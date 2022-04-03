(def description "preprocessor for the ivy array language")

(declare-project
  :name "privy"
  :description description
  :dependencies [])

(declare-executable
 :name "privy"
 :description description
 :entry "main.janet")
