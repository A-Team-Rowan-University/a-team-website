module Config exposing (apiUrl, staticUrl)

import Url.Builder as B


apiUrl : String
apiUrl =
    --B.crossOrigin "http://localhost" [ "api", "v1" ] []
    B.absolute [ "api", "v1" ] []


staticUrl : String
staticUrl =
    B.absolute [ "static" ] []
