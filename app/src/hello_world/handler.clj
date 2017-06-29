(ns hello-world.handler
  (:require [compojure.core :refer :all]
            [compojure.route :as route]
            [ring.middleware.defaults :refer [wrap-defaults site-defaults]]))

(defroutes app-routes
  (GET "/" [] "Hello world, We have continous delivery!<br>Let's update the service.")
  (GET "/wow" [] "Yes, it really works using dynamic ports.")
  (route/not-found "Not Found"))

(def app
  (wrap-defaults app-routes site-defaults))
