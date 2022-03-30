(def output-prefix "#=")

(def tag-peg (peg/compile ~{
  :alphunder (+ (range "az" "AZ") "_")
  :identifier (* :alphunder (any (+ :alphunder :d)))
  :op (* "op" (between 2 3 (* :s+ :identifier)) :s* "=")
  :main (choice
    (* (constant :blank-line) :s* -1)
    (* (constant :assignment) (<- :identifier) :s* "=" (not "="))
    (* (constant :output) ,output-prefix)
    (* (constant :error) "#!")
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
  (let [$i (gensym) $list (gensym)]
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

(defn parse-errors [err]
  (->> err
    (string/trimr)
    (string/split "\n")
    (map |(peg/match error-peg $))))

(defn compiled-lines [tagged-line]
  (match tagged-line
    [:verbose-assignment identifier line] [line identifier `"\x00"`]
    [:statement line] [line `"\x00"`]
    [:comment _] []
    [:output _] []
    [_ line] [line]))

(defn easy-spawn [args input]
  (def process (os/spawn args :pe {:in :pipe :out :pipe :err :pipe}))
  (:write (process :in) input)
  (:close (process :in))
  (def exit (:wait process))
  { :out (:read (process :out) :all)
    :err (:read (process :err) :all)
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
        (print "#= " line))
      (:advance outputs))
    (print "#! unreachable")))

(defn chunk-output [out]
  (def chunks (string/split "\n\0\n" out))
  (if (empty? chunks)
    chunks
    # "\n\0\n" is a terminator, not a seperator, so we
    # remove the last (empty) chunk
    (slice chunks 0 -2)))

(defn expect-output? [tag]
  (match tag
    :statement true
   :verbose-assignment true
   false))

(defn last-index? [i list]
  (= i (dec (length list))))

(defn main [_ file &]
  (def source (slurp file))

  (def tagged-lines
    (->> source
      (string/split "\n")
      (tag-lines)
      (rewrite-verbose-assignments)))

  (def compiled-output (string/join (mapcat compiled-lines tagged-lines) "\n"))

  (def { :exit exit :out out :err err }
    (easy-spawn ["ivy" "/dev/stdin"] compiled-output))

  # this assumes that errors are reported from top to bottom, which feels safe.
  # in practice it seems that one error is ever reported.
  (def errors (iterator (parse-errors err)))

  # we could assert right here that this is less than or equal to the total number we expect.
  # if less, we can also assert a nonzero exit. it should never be greater or something has
  # gone horribly wrong. but...
  (def outputs (iterator (chunk-output out)))

  (var can-print-output false)
  (eachp [i line] tagged-lines
    (when-let [[line-number error-message] (:get errors)]
      # we add one because lines are one-indexed
      (when (= line-number (inc i))
        (print "#! " error-message)
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
