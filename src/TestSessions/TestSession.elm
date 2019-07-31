module TestSessions.TestSession exposing (Id, Msg, Registration, RegistrationId, Session, decoder, newEncoder, registrationDecoder, update, url, view)

import Config exposing (..)
import Dict exposing (Dict)
import Html exposing (Html, button, div, p, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Iso8601
import Json.Decode as Decode
import Json.Encode as Encode
import Network exposing (Notification(..), RequestChange(..))
import Set exposing (Set)
import Time
import Url.Builder as B
import Users.Users as User


url : Id -> String
url id =
    B.relative [ apiUrl, "test_sessions", String.fromInt id ] []


type alias Id =
    Int


type alias RegistrationId =
    Int


type alias Registration =
    { id : RegistrationId
    , taker_id : User.Id
    , registered : Time.Posix
    , opened_test : Maybe Time.Posix
    , submitted_test : Maybe Time.Posix
    , score : Maybe Float
    }


type alias Session =
    { id : Id
    , test_id : Id
    , name : String
    , registrations : List Registration
    , registrations_enabled : Bool
    , opening_enabled : Bool
    , submissions_enabled : Bool
    }


type alias NewSession =
    { test_id : Id
    , name : String
    }


type alias Partial r =
    { r
        | registrations_enabled : Maybe Bool
        , opening_enabled : Maybe Bool
        , submissions_enabled : Maybe Bool
    }


type Msg
    = Registrations Bool
    | Opening Bool
    | Submissions Bool
    | Submitted (Result Http.Error ())


type alias Response =
    { cmd : Cmd Msg
    , requests : List RequestChange
    , reload : Bool
    , notifications : List Notification
    }


update : String -> Msg -> Id -> Response
update id_token msg session_id =
    case msg of
        Registrations enabled ->
            { cmd =
                Http.request
                    { method = "PUT"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = url session_id
                    , body =
                        Http.jsonBody
                            (partialEncoder
                                { registrations_enabled = Just enabled
                                , opening_enabled = Nothing
                                , submissions_enabled = Nothing
                                }
                            )
                    , expect = Http.expectWhatever Submitted
                    , timeout = Nothing
                    , tracker = Just (url session_id)
                    }
            , requests = [ AddRequest (url session_id) ]
            , reload = False
            , notifications = []
            }

        Opening enabled ->
            { cmd =
                Http.request
                    { method = "PUT"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = url session_id
                    , body =
                        Http.jsonBody
                            (partialEncoder
                                { registrations_enabled = Nothing
                                , opening_enabled = Just enabled
                                , submissions_enabled = Nothing
                                }
                            )
                    , expect = Http.expectWhatever Submitted
                    , timeout = Nothing
                    , tracker = Just (url session_id)
                    }
            , requests = [ AddRequest (url session_id) ]
            , reload = False
            , notifications = []
            }

        Submissions enabled ->
            { cmd =
                Http.request
                    { method = "PUT"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = url session_id
                    , body =
                        Http.jsonBody
                            (partialEncoder
                                { registrations_enabled = Nothing
                                , opening_enabled = Nothing
                                , submissions_enabled = Just enabled
                                }
                            )
                    , expect = Http.expectWhatever Submitted
                    , timeout = Nothing
                    , tracker = Just (url session_id)
                    }
            , requests = [ AddRequest (url session_id) ]
            , reload = False
            , notifications = []
            }

        Submitted result ->
            case result of
                Ok _ ->
                    { cmd = Cmd.none
                    , requests = [ RemoveRequest (url session_id) ]
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { cmd = Cmd.none
                    , requests = [ RemoveRequest (url session_id) ]
                    , reload = False
                    , notifications = [ NError "There was a network error" ]
                    }


viewRegistration : Maybe Time.Zone -> Dict User.Id User.User -> Registration -> Html msg
viewRegistration timezone users registration =
    div [ class "box" ]
        [ div [ class "columns" ]
            [ p [ class "title is-5 column" ]
                [ text
                    (Maybe.withDefault
                        "Unknown User"
                        (Maybe.map
                            (\u -> u.first_name ++ " " ++ u.last_name)
                            (Dict.get registration.taker_id users)
                        )
                    )
                ]
            , div [ class "column" ]
                [ button [ class "button is-danger is-pulled-right" ] [ text "Remove" ] ]
            ]
        , div [ class "columns" ]
            [ div [ class "column" ]
                [ text (viewDateTime timezone registration.registered) ]
            , div [ class "column" ]
                [ text (Maybe.withDefault "--" (Maybe.map (viewDateTime timezone) registration.opened_test)) ]
            , div [ class "column" ]
                [ text (Maybe.withDefault "--" (Maybe.map (viewDateTime timezone) registration.submitted_test)) ]
            , div [ class "column" ]
                [ text
                    (Maybe.withDefault "--"
                        (Maybe.map String.fromFloat registration.score)
                    )
                ]
            ]
        ]


viewRegistrations :
    Maybe Time.Zone
    -> Dict User.Id User.User
    -> List Registration
    -> Html msg
viewRegistrations timezone users registrations =
    div []
        [ p [ class "subtitle has-text-centered" ] [ text "Registrations" ]
        , div [] (List.map (viewRegistration timezone users) registrations)
        ]


viewDateTime : Maybe Time.Zone -> Time.Posix -> String
viewDateTime timezone time =
    case timezone of
        Just zone ->
            String.fromInt (viewMonth (Time.toMonth zone time))
                ++ "/"
                ++ String.fromInt (Time.toDay zone time)
                ++ "/"
                ++ String.fromInt (Time.toYear zone time)
                ++ " "
                ++ String.fromInt (Time.toHour zone time)
                ++ ":"
                ++ viewMinute (Time.toMinute zone time)

        Nothing ->
            "no timezone"


viewMinute : Int -> String
viewMinute minute =
    if minute < 10 then
        "0" ++ String.fromInt minute

    else
        String.fromInt minute


viewMonth : Time.Month -> Int
viewMonth month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12


view :
    Maybe Time.Zone
    -> Dict User.Id User.User
    -> Session
    -> Html Msg
view timezone users session =
    div []
        [ p [ class "title has-text-centered" ] [ text session.name ]
        , div []
            [ div [ class "columns" ]
                [ div [ class "column" ]
                    [ p []
                        [ text
                            (if session.registrations_enabled then
                                "Registrations are enabled"

                             else
                                "Registrations are disabled"
                            )
                        ]
                    , button [ class "button", onClick (Registrations (not session.registrations_enabled)) ]
                        [ text
                            (if session.registrations_enabled then
                                "Disable registrations"

                             else
                                "Enable registrations"
                            )
                        ]
                    ]
                , div [ class "column" ]
                    [ p []
                        [ text
                            (if session.opening_enabled then
                                "Opening is enabled"

                             else
                                "Opening is disabled"
                            )
                        ]
                    , button [ class "button", onClick (Opening (not session.opening_enabled)) ]
                        [ text
                            (if session.opening_enabled then
                                "Disable Opening"

                             else
                                "Enable Opening"
                            )
                        ]
                    ]
                , div [ class "column" ]
                    [ p []
                        [ text
                            (if session.submissions_enabled then
                                "Submissions are enabled"

                             else
                                "Submissions are disabled"
                            )
                        ]
                    , button [ class "button", onClick (Submissions (not session.submissions_enabled)) ]
                        [ text
                            (if session.submissions_enabled then
                                "Disable Submissions"

                             else
                                "Enable Submissions"
                            )
                        ]
                    ]
                ]
            ]
        , div [] [ viewRegistrations timezone users session.registrations ]
        ]


registrationDecoder : Decode.Decoder Registration
registrationDecoder =
    Decode.map6 Registration
        (Decode.field "id" Decode.int)
        (Decode.field "taker_id" Decode.int)
        (Decode.field "registered" Iso8601.decoder)
        (Decode.field "opened_test" (Decode.nullable Iso8601.decoder))
        (Decode.field "submitted_test" (Decode.nullable Iso8601.decoder))
        (Decode.field "score" (Decode.nullable Decode.float))


decoder : Decode.Decoder Session
decoder =
    Decode.map7 Session
        (Decode.field "id" Decode.int)
        (Decode.field "test_id" Decode.int)
        (Decode.field "name" Decode.string)
        (Decode.field "registrations" (Decode.list registrationDecoder))
        (Decode.field "registrations_enabled" Decode.bool)
        (Decode.field "opening_enabled" Decode.bool)
        (Decode.field "submissions_enabled" Decode.bool)


newEncoder : NewSession -> Encode.Value
newEncoder session =
    Encode.object
        [ ( "test_id", Encode.int session.test_id )
        , ( "name", Encode.string session.name )
        ]


partialEncoder : Partial r -> Encode.Value
partialEncoder session =
    Encode.object
        ([]
            |> (\l ->
                    case session.registrations_enabled of
                        Just registrations_enabled ->
                            ( "registrations_enabled", Encode.bool registrations_enabled ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case session.opening_enabled of
                        Just opening_enabled ->
                            ( "opening_enabled", Encode.bool opening_enabled ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case session.submissions_enabled of
                        Just submissions_enabled ->
                            ( "submissions_enabled", Encode.bool submissions_enabled ) :: l

                        Nothing ->
                            l
               )
        )
