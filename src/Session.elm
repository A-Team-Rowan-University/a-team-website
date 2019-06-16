port module Session exposing
    ( GoogleUser
    , Session(..)
    , googleUserDecoder
    , idToken
    )

import Http
import Json.Decode as D
import Json.Decode.Pipeline as P


type Session userid
    = NotSignedIn
    | SignedIn GoogleUser
    | Validated userid GoogleUser
    | GoogleError D.Error
    | NetworkError Http.Error
    | AccessDenied


type alias GoogleUser =
    { first_name : Maybe String
    , last_name : Maybe String
    , email : Maybe String
    , image_url : Maybe String
    , id_token : String
    , expires_in : Int
    , first_issued_at : Int
    , expires_at : Int
    }


{-| Extract the Id Token from the signed in user if
they are signed in and validated
-}
idToken : Session userid -> Maybe String
idToken session =
    case session of
        NotSignedIn ->
            Nothing

        SignedIn _ ->
            Nothing

        Validated user google_user ->
            Just google_user.id_token

        GoogleError _ ->
            Nothing

        NetworkError _ ->
            Nothing

        AccessDenied ->
            Nothing


googleUserDecoder : D.Decoder GoogleUser
googleUserDecoder =
    D.succeed GoogleUser
        |> P.required "given_name" (D.nullable D.string)
        |> P.required "family_name" (D.nullable D.string)
        |> P.required "email" (D.nullable D.string)
        |> P.required "image_url" (D.nullable D.string)
        |> P.required "id_token" D.string
        |> P.required "expires_in" D.int
        |> P.required "first_issued_at" D.int
        |> P.required "expires_at" D.int
