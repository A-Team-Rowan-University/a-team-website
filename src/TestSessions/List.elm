module TestSessions.List exposing (Msg, decoder, update, url, view)

import Config exposing (..)
import Dict exposing (Dict)
import Html exposing (Html, a, button, div, p, span, text)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import Network exposing (Notification(..), RequestChange(..))
import TestSessions.TestSession exposing (Id, Session)
import Tests.List exposing (Test)
import Url.Builder as B
import Users.Users as User


url : String
url =
    B.relative [ apiUrl, "test_sessions/" ] []


urlRegister : Id -> String
urlRegister id =
    B.relative [ apiUrl, "test_sessions", String.fromInt id, "register" ] []


type Msg
    = Register Id
    | Submitted Id (Result Http.Error ())


type alias Response =
    { cmd : Cmd Msg
    , requests : List RequestChange
    , reload : Bool
    , notifications : List Notification
    }


update : String -> Msg -> Response
update id_token msg =
    case msg of
        Register session_id ->
            { cmd =
                Http.request
                    { method = "POST"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = urlRegister session_id
                    , body = Http.emptyBody
                    , expect = Http.expectWhatever (Submitted session_id)
                    , timeout = Nothing
                    , tracker = Just (urlRegister session_id)
                    }
            , requests = [ AddRequest (urlRegister session_id) ]
            , reload = False
            , notifications = []
            }

        Submitted session_id result ->
            case result of
                Ok _ ->
                    { cmd = Cmd.none
                    , requests =
                        [ RemoveRequest (urlRegister session_id) ]
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { cmd = Cmd.none
                    , requests =
                        [ RemoveRequest (urlRegister session_id) ]
                    , reload = False
                    , notifications =
                        [ NError
                            "There was a network error registering"
                        ]
                    }


viewTestSession : User.Id -> Session -> Html Msg
viewTestSession userid testsession =
    let
        registered =
            List.length
                (List.filter (\r -> r.taker_id == userid)
                    testsession.registrations
                )
                > 0

        action =
            case
                ( testsession.registrations_enabled
                , testsession.opening_enabled
                , registered
                )
            of
                ( True, _, False ) ->
                    [ button
                        [ class "button is-primary"
                        , onClick (Register testsession.id)
                        ]
                        [ text "Register" ]
                    ]

                ( True, False, True ) ->
                    [ text "Registered" ]

                ( _, True, True ) ->
                    [ button [ class "button is-primary" ] [ text "Take" ] ]

                ( False, True, False ) ->
                    [ text "Closed" ]

                ( False, False, _ ) ->
                    [ text "Closed" ]
    in
    div
        [ class "box" ]
        [ div [ class "columns title is-5" ]
            [ p [ class "column" ] [ text testsession.name ]
            , span [ class "column" ]
                [ a
                    [ href
                        (B.absolute
                            [ "tests", "sessions", String.fromInt testsession.id ]
                            []
                        )
                    , class "button is-pulled-right"
                    ]
                    [ text "Details" ]
                ]
            ]
        , div [ class "columns subtitle is-5" ]
            [ p [ class "column" ]
                [ text
                    (String.fromInt (List.length testsession.registrations)
                        ++ " registrations"
                    )
                ]
            , span [ class "column" ] [ span [ class "is-pulled-right" ] action ]
            ]
        ]


view : User.Id -> Dict Id Session -> Maybe Test -> Html Msg
view userid testsessions test_filter =
    let
        title =
            case test_filter of
                Just test ->
                    "Test Sessions for " ++ test.name

                Nothing ->
                    "Test Sessions"

        filtered_sessions =
            case test_filter of
                Just test ->
                    Dict.filter (\id session -> session.test_id == test.id)
                        testsessions

                Nothing ->
                    testsessions
    in
    div []
        [ p [ class "title has-text-centered" ] [ text title ]
        , div [ class "columns" ]
            [ div [ class "column is-one-fifth" ]
                [ p [ class "title is-4 has-text-centered" ] [ text "Search" ]
                , p [ class "has-text-centered" ] [ text "Working on it :)" ]
                ]
            , div [ class "column" ]
                [ div []
                    (List.map (viewTestSession userid)
                        (Dict.values filtered_sessions)
                    )
                , a [ class "button is-primary", href "/tests/sessions/new" ]
                    [ text "New Test Session" ]
                ]
            ]
        ]


decoder : Decode.Decoder (List TestSessions.TestSession.Session)
decoder =
    Decode.field "test_sessions" (Decode.list TestSessions.TestSession.decoder)
