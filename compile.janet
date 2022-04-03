(def output-prefix "#=")
(def error-prefix "#!")

(defn terminated-by [terminator str]
  (def components (string/split terminator str))
  (if (empty? components)
    components
    (do
      (assert (empty? (last components)) "unterminated string")
      (tuple/slice components 0 -2))))

(def tag-peg (peg/compile ~{
  :alphunder (+ (range "az" "AZ") "_")
  :identifier (* :alphunder (any (+ :alphunder :d)))
  :op (* "op" (between 2 3 (* :s+ :identifier)) :s* "=")
  :main (choice
    (* (constant :blank-line) :s* -1)
    (* (constant :assignment) (<- :identifier) :s* "=" (not "="))
    (* (constant :output) ,output-prefix)
    (* (constant :error) ,error-prefix)
    (* (constant :comment) "#")
    (* (constant :long-op) :op :s* -1)
    (* (constant :short-op) :op)
    (constant :statement))
  }))

(def error-peg (peg/compile ~(some (* "/dev/stdin:" (/ (<- :d+) ,scan-number) ": " (<- (thru -1))))))

(defn tag-lines [lines]
  (var in-multi-line-op false)
  (def tagged-lines @[])

  (each line lines
    (def tags (peg/match tag-peg line))
    (array/push tagged-lines [;(if in-multi-line-op [:continuation] tags) line])
    (match tags
      [:long-op] (set in-multi-line-op true)
      [:blank-line] (set in-multi-line-op false)))
  tagged-lines)

(defmacro each-reverse [identifier list & body]
  (with-syms [$i $list]
    ~(let [,$list ,list]
      (var ,$i (dec (length ,$list)))
      (while (>= ,$i 0)
        (def ,identifier (in ,$list ,$i))
        ,;body
        (-- ,$i)))))

(defn rewrite-verbose-assignments [tagged-lines]
  (var result @[])
  (var make-verbose false)
  (each-reverse line tagged-lines
    (match line
      [:assignment identifier contents]
        (if make-verbose
          (array/push result [:verbose-assignment identifier contents])
          (array/push result [:assignment contents]))
      (array/push result line))
    (match line
      [:output _] (set make-verbose true)
      _ (set make-verbose false)))
  (reverse! result)
  result)

(defn map-first [f list]
  (map (fn [[x y]] [(f x) y]) list))

(defn parse-errors [err sourcemap]
  (->> err
    (terminated-by "\n")
    (map |(peg/match error-peg $))
    (map-first |(in sourcemap (dec $)))))

(defn compiled-lines [tagged-line]
  (match tagged-line
    [:verbose-assignment identifier line] [line identifier `"\x00"`]
    [:statement line] [line `"\x00"`]
    [:comment _] []
    [:output _] []
    [_ line] [line]))

# if there's no output, this will return nil instead of
# the empty string, for some reason
(defn read-pipe [file]
  (or (:read file :all) ""))

(defn easy-spawn [args input]
  (def process (os/spawn args :pe {:in :pipe :out :pipe :err :pipe}))
  (:write (process :in) input)
  (:close (process :in))
  (def exit (:wait process))
  { :out (read-pipe (process :out))
    :err (read-pipe (process :err))
    :exit exit })

(def iterator-proto @{
  :get (fn [self]
    (let [i (self :i) list (self :list)]
    (if (< i (length list))
      (in list i)
      nil)))
  :advance (fn [self] (++ (self :i)))
  })

(defn iterator [list]
  (def iterator @{:i 0 :list list})
  (table/setproto iterator iterator-proto))

(defn print-line-with-output [line outputs]
  (print line)
  (if-let [output (:get outputs)]
    (do
      (each line (string/split "\n" output)
        (print output-prefix " " line))
      (:advance outputs))
    (print error-prefix " unreachable")))

(defn expect-output? [tag]
  (match tag
    :statement true
   :verbose-assignment true
   false))

(defn last-index? [i list]
  (= i (dec (length list))))

# returns a tuple of the mapcat result and an
# array associating output indices to the input
# indices that produced them
(defn sourcemapcat [f list]
  (def result @[])
  (def index-mappings @[])
  (eachp (i line) list
    (def mapped (f line))
    (each _ mapped (array/push index-mappings i))
    (array/concat result mapped))
  [result index-mappings])

(defn main [&]
  (def source (:read stdin :all))

  (def tagged-lines
    (->> source
      (string/split "\n")
      (tag-lines)
      (rewrite-verbose-assignments)))

  (def [compiled-lines sourcemap] (sourcemapcat compiled-lines tagged-lines))
  (def compiled-output (string/join compiled-lines "\n"))

  (def { :exit exit :out out :err err }
    (easy-spawn ["ivy" "/dev/stdin"] compiled-output))

  # this assumes that errors are reported from top to bottom, which feels safe.
  # in practice it seems that one error is ever reported.
  (def errors (iterator (parse-errors err sourcemap)))

  # we could assert right here that this is less than or equal to the total number we expect.
  # if less, we can also assert a nonzero exit. it should never be greater or something has
  # gone horribly wrong. but...
  (def outputs (iterator (terminated-by "\n\0\n" out)))

  (var can-print-output false)
  (eachp [i line] tagged-lines
    (when-let [[line-index error-message] (:get errors)]
      (when (= line-index i)
        (print error-prefix " " error-message)
        (:advance errors)))

    (when (and (nil? (:get outputs)) (expect-output? (first line)))
      (set can-print-output true))

    (match line
      [:statement line] (print-line-with-output line outputs)
      [:verbose-assignment _identifier line] (print-line-with-output line outputs)
      [:output line] (when can-print-output (print line))
      [:error _] ()
      # so that we don't add an extra newline to the end...
      [:blank-line ""] (when (not (last-index? i tagged-lines)) (print))
      [_ line] (print line))))
