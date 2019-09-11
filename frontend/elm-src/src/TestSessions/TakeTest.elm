module TestSessions.TakeTest exposing (AnonymousQuestion, Msg, QuestionId, State, loadData, update, view)

import Config exposing (..)
import Dict exposing (Dict)
import Errors
import Html exposing (Html, a, button, div, p, text)
import Html.Attributes exposing (class, download, href)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Network exposing (RequestChange(..))
import Response exposing (Response)
import Session exposing (Session)
import TestSessions.TestSession exposing (Id, Registration, registrationDecoder)
import Url.Builder as B


submitUrl : Id -> String
submitUrl id =
    B.relative [ apiUrl, "test_sessions", String.fromInt id, "submit" ] []


openUrl : Id -> String
openUrl id =
    B.relative [ apiUrl, "test_sessions", String.fromInt id, "open" ] []


type alias QuestionId =
    Int


type alias AnonymousQuestion =
    { id : QuestionId
    , title : String
    , answer_1 : String
    , answer_2 : String
    , answer_3 : String
    , answer_4 : String
    }


anonymousQuestionDecoder : Decode.Decoder AnonymousQuestion
anonymousQuestionDecoder =
    Decode.map6 AnonymousQuestion
        (Decode.field "id" Decode.int)
        (Decode.field "title" Decode.string)
        (Decode.field "answer_1" Decode.string)
        (Decode.field "answer_2" Decode.string)
        (Decode.field "answer_3" Decode.string)
        (Decode.field "answer_4" Decode.string)


anonymousQuestionListDecoder : Decode.Decoder (List AnonymousQuestion)
anonymousQuestionListDecoder =
    Decode.field "questions" (Decode.list anonymousQuestionDecoder)


type alias ResponseQuestion =
    { id : QuestionId
    , answer : String
    }


responseQuestionEncoder : ResponseQuestion -> Encode.Value
responseQuestionEncoder question =
    Encode.object
        [ ( "id", Encode.int question.id )
        , ( "answer", Encode.string question.answer )
        ]


responseQuestionListEncoder : List ResponseQuestion -> Encode.Value
responseQuestionListEncoder questions =
    Encode.object [ ( "questions", Encode.list responseQuestionEncoder questions ) ]


type State
    = Taking (Dict QuestionId ( AnonymousQuestion, Maybe String ))
    | Submitting
    | Done Registration


loadData : String -> TestSessions.TestSession.Id -> ( Cmd Msg, List RequestChange, List Errors.Error )
loadData id_token test_session_id =
    ( Http.request
        { method = "GET"
        , headers = [ Http.header "id_token" id_token ]
        , url = openUrl test_session_id
        , body = Http.emptyBody
        , expect = Errors.expectJsonWithError Loaded anonymousQuestionListDecoder
        , timeout = Nothing
        , tracker = Just (submitUrl test_session_id)
        }
    , [ AddRequest (openUrl test_session_id) ]
    , []
    )


type Msg
    = Loaded (Result Errors.Error (List AnonymousQuestion))
    | ResponseClicked QuestionId String
    | Submit
    | Submitted (Result Errors.Error Registration)


foldQuestions :
    ( AnonymousQuestion, Maybe String )
    -> Maybe (List ResponseQuestion)
    -> Maybe (List ResponseQuestion)
foldQuestions ( question, response ) submission =
    case ( submission, response ) of
        ( Just responses, Just answer ) ->
            Just ({ id = question.id, answer = answer } :: responses)

        _ ->
            Nothing


update : String -> TestSessions.TestSession.Id -> Maybe State -> Msg -> Response (Maybe State) Msg
update id_token test_session_id state msg =
    case msg of
        Loaded result ->
            case result of
                Ok questions ->
                    { state =
                        Just
                            (Taking
                                (Dict.fromList (List.map (\q -> ( q.id, ( q, Nothing ) )) questions))
                            )
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest (openUrl test_session_id) ]
                    , reload = False
                    , done = False
                    , errors = []
                    }

                Err err ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest (openUrl test_session_id) ]
                    , reload = False
                    , done = False
                    , errors = [ err ]
                    }

        ResponseClicked questionid response ->
            case state of
                Just (Taking questions) ->
                    Response.state
                        (Just
                            (Taking
                                (Dict.update questionid
                                    (\m ->
                                        case m of
                                            Just ( q, r ) ->
                                                Just ( q, Just response )

                                            Nothing ->
                                                Nothing
                                    )
                                    questions
                                )
                            )
                        )

                _ ->
                    Response.state state

        Submit ->
            case state of
                Just (Taking questions) ->
                    let
                        submission =
                            List.foldl foldQuestions (Just []) (Dict.values questions)
                    in
                    case submission of
                        Just responses ->
                            { state = state
                            , cmd =
                                Http.request
                                    { method = "POST"
                                    , headers = [ Http.header "id_token" id_token ]
                                    , url = submitUrl test_session_id
                                    , body = Http.jsonBody (responseQuestionListEncoder responses)
                                    , expect = Errors.expectJsonWithError Submitted registrationDecoder
                                    , timeout = Nothing
                                    , tracker = Just (submitUrl test_session_id)
                                    }
                            , requests = [ AddRequest (submitUrl test_session_id) ]
                            , reload = False
                            , done = False
                            , errors = []
                            }

                        Nothing ->
                            { state = state
                            , cmd = Cmd.none
                            , requests = []
                            , reload = False
                            , done = False
                            , errors = [ Errors.TestNotComplete ]
                            }

                _ ->
                    Response.state state

        Submitted result ->
            case result of
                Ok registration ->
                    { state = Just (Done registration)
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest (submitUrl test_session_id) ]
                    , reload = False
                    , done = False
                    , errors = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest (submitUrl test_session_id) ]
                    , reload = False
                    , done = False
                    , errors = [ e ]
                    }


viewAnswer : QuestionId -> String -> Maybe String -> Html Msg
viewAnswer id answer response =
    let
        btnclass =
            if Just answer == response then
                class "box is-fullwidth has-background-primary"

            else
                class "box is-fullwidth"
    in
    div [ btnclass, onClick (ResponseClicked id answer) ] [ text answer ]


viewQuestion : ( AnonymousQuestion, Maybe String ) -> Html Msg
viewQuestion ( question, response ) =
    div [ class "box" ]
        [ p [ class "title is-5" ] [ text question.title ]
        , viewAnswer question.id question.answer_1 response
        , viewAnswer question.id question.answer_2 response
        , viewAnswer question.id question.answer_3 response
        , viewAnswer question.id question.answer_4 response
        ]


viewSubmitted : Registration -> Html msg
viewSubmitted registration =
    case registration.score of
        Just score ->
            div []
                [ p []
                    [ text
                        ("You got a score of " ++ (String.fromFloat (toFloat (round (score * 10000.0)) / 100.0) ++ "%"))
                    ]
                , if score >= 0.8 then
                    a
                        [ class "button"
                        , href
                            (B.relative
                                [ apiUrl
                                , "test_sessions"
                                , "certificates"
                                , String.fromInt registration.id
                                ]
                                []
                            )
                        , download "certificate.png"
                        ]
                        [ text "Download certificate" ]

                  else
                    div [] []
                ]

        Nothing ->
            p [] [ text "You test has not been graded yet" ]


view : Maybe State -> Html Msg
view state =
    case state of
        Just s ->
            case s of
                Taking questions ->
                    div []
                        [ div [] (List.map viewQuestion (Dict.values questions))
                        , button [ class "button is-primary", onClick Submit ] [ text "Submit" ]
                        ]

                Submitting ->
                    p [] [ text "Submitting questions" ]

                Done registration ->
                    viewSubmitted registration

        Nothing ->
            p [] [ text "Loading questions" ]
