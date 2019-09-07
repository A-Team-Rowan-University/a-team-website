module Errors exposing
    ( Display
    , Error(..)
    , display
    , expectJsonWithError
    , expectWhateverWithError
    , expectWithError
    )

import Http
import Json.Decode as Decode


type Error
    = GoogleLogin
    | ValidationLogin
    | NotLoggedIn
    | Permission String
    | BadUrl String
    | NetworkTimeout
    | UnknownNetwork
    | InternalServer String
    | Conflict String
    | BadResponse String
    | NotImplemented String
    | TestNotComplete


type alias Display =
    { title : String
    , description : String
    }


display : Error -> Display
display error =
    case error of
        GoogleLogin ->
            { title = "Google login error"
            , description = "Failed to login to Google"
            }

        ValidationLogin ->
            { title = "Login validation error"
            , description = "Failed to validate your email with our database"
            }

        NotLoggedIn ->
            { title = "Not logged in"
            , description = "You must be logged in"
            }

        Permission permission ->
            { title = "Permission Denied!"
            , description = "You do not have permission to " ++ permission
            }

        BadUrl url ->
            { title = "Bad url: " ++ url
            , description =
                """
                An invalid URL was provided for this request.
                Please report this error.
                """
            }

        NetworkTimeout ->
            { title = "Network Timeout"
            , description =
                """
                The network request timed out.
                The server is either down, not responding, or not reachable.
                Please try again later and report this error.
                """
            }

        UnknownNetwork ->
            { title = "Unknown network error"
            , description =
                """
                There was an error connecting to the network.
                Are you connected?
                """
            }

        InternalServer e ->
            { title = "Internal server error: " ++ e
            , description =
                """
                Our server had an error.
                Please report this error.
                """
            }

        Conflict e ->
            { title = "There was a conflict"
            , description = e
            }

        BadResponse e ->
            { title = "Bad response from the server"
            , description =
                """
                The server responded incorrectly.
                Please report this error.
                """ ++ e
            }

        NotImplemented url ->
            { title = "This function is not yet implemented on the server"
            , description = url
            }

        TestNotComplete ->
            { title = "Answer all the questions!"
            , description = "You may not submit the test until all the questions are answered"
            }


expectWhateverWithError : (Result Error () -> msg) -> Http.Expect msg
expectWhateverWithError to_msg =
    expectWithError to_msg <| \metadata body -> Ok ()


expectJsonWithError : (Result Error a -> msg) -> Decode.Decoder a -> Http.Expect msg
expectJsonWithError to_msg decoder =
    expectWithError to_msg <|
        \metadata body ->
            case Decode.decodeString decoder body of
                Ok value ->
                    Ok value

                Err err ->
                    Err (BadResponse (Decode.errorToString err))


expectWithError :
    (Result Error a -> msg)
    -> (Http.Metadata -> String -> Result Error a)
    -> Http.Expect msg
expectWithError to_msg on_response =
    Http.expectStringResponse to_msg <|
        \response ->
            case response of
                Http.BadUrl_ url ->
                    Err (BadUrl url)

                Http.Timeout_ ->
                    Err NetworkTimeout

                Http.NetworkError_ ->
                    Err UnknownNetwork

                Http.BadStatus_ metadata body ->
                    case metadata.statusCode of
                        500 ->
                            Err (InternalServer body)

                        400 ->
                            Err (InternalServer body)

                        404 ->
                            Err (InternalServer body)

                        401 ->
                            case body of
                                "Permission denied!" ->
                                    Err (Permission metadata.url)

                                "Failed to validate Id Token with Google" ->
                                    Err ValidationLogin

                                "Google did not provide an email" ->
                                    Err ValidationLogin

                                "The email provided by Google did not match any users' emails" ->
                                    Err ValidationLogin

                                _ ->
                                    Err (Permission metadata.url)

                        409 ->
                            Err (Conflict body)

                        501 ->
                            Err (NotImplemented metadata.url)

                        _ ->
                            Err UnknownNetwork

                Http.GoodStatus_ metadata body ->
                    on_response metadata body
