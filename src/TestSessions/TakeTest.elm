module TestSessions.TakeTest exposing (AnonymousQuestion, Msg, QuestionId, State, loadData, update, view)

import Config exposing (..)
import Dict exposing (Dict)
import Errors
import Html exposing (Html, button, div, p, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Network exposing (RequestChange(..))
import Response exposing (Response)
import Session exposing (Session)
import TestSessions.TestSession exposing (Id)
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


type alias State =
    { questions : Dict QuestionId ( AnonymousQuestion, Maybe String ) }


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
    | Submitted (Result Errors.Error ())


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
                            { questions =
                                Dict.fromList
                                    (List.map (\q -> ( q.id, ( q, Nothing ) )) questions)
                            }
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
                Just s ->
                    { state =
                        Just
                            { s
                                | questions =
                                    Dict.update questionid
                                        (\m ->
                                            case m of
                                                Just ( q, r ) ->
                                                    Just ( q, Just response )

                                                Nothing ->
                                                    Nothing
                                        )
                                        s.questions
                            }
                    , cmd = Cmd.none
                    , requests = []
                    , reload = False
                    , done = False
                    , errors = []
                    }

                Nothing ->
                    { state = Nothing
                    , cmd = Cmd.none
                    , requests = []
                    , reload = False
                    , done = False
                    , errors = []
                    }

        Submit ->
            case state of
                Just s ->
                    let
                        submission =
                            List.foldl foldQuestions (Just []) (Dict.values s.questions)
                    in
                    case submission of
                        Just responses ->
                            { state = Just s
                            , cmd =
                                Http.request
                                    { method = "POST"
                                    , headers = [ Http.header "id_token" id_token ]
                                    , url = submitUrl test_session_id
                                    , body = Http.jsonBody (responseQuestionListEncoder responses)
                                    , expect = Errors.expectWhateverWithError Submitted
                                    , timeout = Nothing
                                    , tracker = Just (submitUrl test_session_id)
                                    }
                            , requests = [ AddRequest (submitUrl test_session_id) ]
                            , reload = False
                            , done = False
                            , errors = []
                            }

                        Nothing ->
                            { state = Just s
                            , cmd = Cmd.none
                            , requests = []
                            , reload = False
                            , done = False
                            , errors = [ Errors.TestNotComplete ]
                            }

                Nothing ->
                    { state = Nothing
                    , cmd = Cmd.none
                    , requests = []
                    , reload = False
                    , done = False
                    , errors = []
                    }

        Submitted result ->
            case result of
                Ok _ ->
                    { state = Nothing
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest (submitUrl test_session_id) ]
                    , reload = False
                    , done = True
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
                class "button is-fullwidth is-primary"

            else
                class "button is-fullwidth"
    in
    button [ btnclass, onClick (ResponseClicked id answer) ] [ text answer ]


viewQuestion : ( AnonymousQuestion, Maybe String ) -> Html Msg
viewQuestion ( question, response ) =
    div [ class "box" ]
        [ p [ class "title is-5" ] [ text question.title ]
        , viewAnswer question.id question.answer_1 response
        , viewAnswer question.id question.answer_2 response
        , viewAnswer question.id question.answer_3 response
        , viewAnswer question.id question.answer_4 response
        ]


view : Maybe State -> Html Msg
view state =
    case state of
        Just s ->
            div []
                [ div [] (List.map viewQuestion (Dict.values s.questions))
                , button [ class "button is-primary", onClick Submit ] [ text "Submit" ]
                ]

        Nothing ->
            p [] [ text "Loading questions" ]
