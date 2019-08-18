module Response exposing (Response)

import Errors
import Network


type alias Response s msg =
    { state : s
    , cmd : Cmd msg
    , requests : List Network.RequestChange
    , reload : Bool
    , done : Bool
    , errors : List Errors.Error
    }
