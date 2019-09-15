module TestSessions.List exposing (Msg, State, decoder, init, update, url, view)

import Config exposing (..)
import Dict exposing (Dict)
import Errors
import Html exposing (Html, a, button, div, input, p, span, text)
import Html.Attributes exposing (class, href, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode
import Network exposing (RequestChange(..))
import Response exposing (Response)
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


urlUnregister : Id -> String
urlUnregister id =
    B.relative [ apiUrl, "test_sessions", String.fromInt id, "unregister" ] []


type alias State =
    { new_test_session : Maybe ( String, Int ) }


init : State
init =
    { new_test_session = Nothing }


type Msg
    = EditNewTestSession String Int
    | SubmitNewTestSession Id String Int
    | SubmittedNewTestSession (Result Errors.Error ())
    | Register Id
    | Registered Id (Result Errors.Error ())
    | Unregister Id
    | Unregistered Id (Result Errors.Error ())


update : String -> State -> Msg -> Response State Msg
update id_token state msg =
    case msg of
        EditNewTestSession name max_registrations ->
            { state = { state | new_test_session = Just ( name, max_registrations ) }
            , cmd = Cmd.none
            , requests = []
            , reload = False
            , done = False
            , errors = []
            }

        SubmitNewTestSession test_id name max_registrations ->
            --curl --data '{
            --    "test_id": 1,
            --    "name": "ECE Safety Test Session 1"
            --}' -H id_token:$ID_TOKEN  $URL/test_sessions/
            { state = state
            , cmd =
                Http.request
                    { method = "POST"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = url
                    , body =
                        Http.jsonBody
                            (TestSessions.TestSession.newEncoder
                                { test_id = test_id, name = name, max_registrations = max_registrations }
                            )
                    , expect = Errors.expectWhateverWithError SubmittedNewTestSession
                    , timeout = Nothing
                    , tracker = Just url
                    }
            , requests = [ AddRequest url ]
            , reload = False
            , done = False
            , errors = []
            }

        SubmittedNewTestSession result ->
            case result of
                Ok _ ->
                    { state = init
                    , cmd = Cmd.none
                    , requests =
                        [ RemoveRequest url ]
                    , reload = True
                    , done = False
                    , errors = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ RemoveRequest url ]
                    , reload = False
                    , done = False
                    , errors = [ e ]
                    }

        Register session_id ->
            { state = state
            , cmd =
                Http.request
                    { method = "POST"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = urlRegister session_id
                    , body = Http.emptyBody
                    , expect = Errors.expectWhateverWithError (Registered session_id)
                    , timeout = Nothing
                    , tracker = Just (urlRegister session_id)
                    }
            , requests = [ AddRequest (urlRegister session_id) ]
            , reload = False
            , done = False
            , errors = []
            }

        Registered session_id result ->
            case result of
                Ok _ ->
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ RemoveRequest (urlRegister session_id) ]
                    , reload = True
                    , done = False
                    , errors = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ RemoveRequest (urlRegister session_id) ]
                    , reload = False
                    , done = False
                    , errors = [ e ]
                    }

        Unregister session_id ->
            { state = state
            , cmd =
                Http.request
                    { method = "POST"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = urlUnregister session_id
                    , body = Http.emptyBody
                    , expect = Errors.expectWhateverWithError (Unregistered session_id)
                    , timeout = Nothing
                    , tracker = Just (urlUnregister session_id)
                    }
            , requests = [ AddRequest (urlUnregister session_id) ]
            , reload = False
            , done = False
            , errors = []
            }

        Unregistered session_id result ->
            case result of
                Ok _ ->
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ RemoveRequest (urlUnregister session_id) ]
                    , reload = True
                    , done = False
                    , errors = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ RemoveRequest (urlUnregister session_id) ]
                    , reload = False
                    , done = False
                    , errors = [ e ]
                    }


viewTestSession : User.Id -> Session -> Html Msg
viewTestSession userid testsession =
    let
        registered =
            List.head (List.filter (\r -> r.taker_id == userid) testsession.registrations) |> Maybe.map (\r -> r.score)

        action =
            case
                ( testsession.registrations_enabled
                , testsession.opening_enabled
                , registered
                )
            of
                ( False, _, Nothing ) ->
                    [ text "Closed" ]

                ( True, _, Nothing ) ->
                    if Maybe.map (\r -> List.length testsession.registrations < r) testsession.max_registrations |> Maybe.withDefault False then
                        [ button
                            [ class "button is-primary"
                            , onClick (Register testsession.id)
                            ]
                            [ text "Register" ]
                        ]

                    else
                        [ text "Full" ]

                ( _, False, Just Nothing ) ->
                    [ text "Registered" ]

                ( _, True, Just Nothing ) ->
                    [ a
                        [ class "button is-primary"
                        , href (B.absolute [ "tests", "sessions", String.fromInt testsession.id, "take" ] [])
                        ]
                        [ text "Take" ]
                    ]

                ( _, _, Just (Just score) ) ->
                    let
                        s =
                            String.fromFloat (score * 100)
                    in
                    [ text ("Taken (" ++ (String.split "." s |> List.head |> Maybe.withDefault s) ++ "%)") ]

        unreigster =
            case registered of
                Just Nothing ->
                    [ button [ class "button is-danger", onClick (Unregister testsession.id) ] [ text "Unregister" ] ]

                _ ->
                    []
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
                        ++ " / "
                        ++ Maybe.withDefault "inf" (Maybe.map String.fromInt testsession.max_registrations)
                        ++ " registrations"
                    )
                ]
            , span [ class "column" ] [ span [ class "is-pulled-right" ] (action ++ unreigster) ]
            ]
        ]


view : User.Id -> Dict Id Session -> Maybe Test -> State -> Html Msg
view userid testsessions test_filter state =
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
                , case test_filter of
                    Just test ->
                        case state.new_test_session of
                            Just ( name, max_registrations ) ->
                                div [ class "field has-addons" ]
                                    [ div [ class "control" ]
                                        [ input
                                            [ class "input"
                                            , value name
                                            , onInput (\s -> EditNewTestSession s max_registrations)
                                            ]
                                            []

                                        -- TODO Allow creating test session with no limit
                                        , input
                                            [ class "input"
                                            , value (String.fromInt max_registrations)
                                            , onInput (\s -> EditNewTestSession name (Maybe.withDefault 0 (String.toInt s)))
                                            ]
                                            []
                                        ]
                                    , div [ class "control" ]
                                        [ button
                                            [ class "button is-primary"
                                            , onClick (SubmitNewTestSession test.id name max_registrations)
                                            ]
                                            [ text "Submit" ]
                                        ]
                                    ]

                            Nothing ->
                                button [ class "button is-primary", onClick (EditNewTestSession "" 0) ]
                                    [ text "New Test Session" ]

                    Nothing ->
                        p [] []
                ]
            ]
        ]


decoder : Decode.Decoder (List TestSessions.TestSession.Session)
decoder =
    Decode.field "test_sessions" (Decode.list TestSessions.TestSession.decoder)
