module Response exposing (Response, http, state)

import Errors
import Http
import Network exposing (RequestChange(..))


type alias Response s msg =
    { state : s
    , cmd : Cmd msg
    , requests : List Network.RequestChange
    , reload : Bool
    , done : Bool
    , errors : List Errors.Error
    }


state : s -> Response s msg
state s =
    { state = s
    , cmd = Cmd.none
    , requests = []
    , reload = False
    , done = False
    , errors = []
    }


http : s -> String -> String -> String -> Http.Body -> Http.Expect msg -> Response s msg
http s id_token method url body expect =
    { state = s
    , cmd =
        Http.request
            { method = method
            , headers = [ Http.header "id_token" id_token ]
            , url = url
            , body = body
            , expect = expect
            , timeout = Nothing
            , tracker = Just url
            }
    , requests = [ AddRequest url ]
    , done = False
    , reload = False
    , errors = []
    }
