module Questions exposing
    ( Msg
    , Question
    , QuestionId
    , State
    , init
    , questionListDecoder
    , questionsUrl
    , update
    , viewCategories
    , viewCategoryDetail
    )

import Config exposing (..)
import Dict exposing (Dict)
import Errors
import Html exposing (Html, a, button, div, input, p, span, text)
import Html.Attributes exposing (class, href, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Network exposing (RequestChange(..))
import Response exposing (Response)
import Tests.List exposing (QuestionCategory, QuestionCategoryId)
import Url.Builder as B
import Users.Users as Users


questionsUrl : String
questionsUrl =
    B.relative [ apiUrl, "questions/" ] []


questionUrl : QuestionId -> String
questionUrl id =
    B.relative [ apiUrl, "questions", String.fromInt id ] []


type alias QuestionId =
    Int


type alias Question =
    { id : QuestionId
    , category_id : QuestionCategoryId
    , title : String
    , correct_answer : String
    , incorrect_answer_1 : String
    , incorrect_answer_2 : String
    , incorrect_answer_3 : String
    }


type alias NewQuestion =
    { category_id : QuestionCategoryId
    , title : String
    , correct_answer : String
    , incorrect_answer_1 : String
    , incorrect_answer_2 : String
    , incorrect_answer_3 : String
    }


type alias PartialQuestion =
    { title : Maybe String
    , correct_answer : Maybe String
    , incorrect_answer_1 : Maybe String
    , incorrect_answer_2 : Maybe String
    , incorrect_answer_3 : Maybe String
    }


type alias State =
    { questions : Dict QuestionId PartialQuestion
    , new_question : Maybe NewQuestion
    }


init : State
init =
    { questions = Dict.empty
    , new_question = Nothing
    }


type Msg
    = AddNewQuestion QuestionCategoryId
    | EditNewQuestionTitle String
    | EditNewQuestionCorrectAnswer String
    | EditNewQuestionIncorrectAnswer1 String
    | EditNewQuestionIncorrectAnswer2 String
    | EditNewQuestionIncorrectAnswer3 String
    | SubmitNewQuestion
    | SubmittedNewQuestion (Result Errors.Error ())
    | CancelNewQuestion
    | RemoveQuestion QuestionId
    | RemovedQuestion QuestionId (Result Errors.Error ())
    | EditTitle QuestionId (Maybe String)
    | EditCorrectAnswer QuestionId (Maybe String)
    | EditIncorrectAnswer1 QuestionId (Maybe String)
    | EditIncorrectAnswer2 QuestionId (Maybe String)
    | EditIncorrectAnswer3 QuestionId (Maybe String)
    | SubmitEdits QuestionId
    | SubmittedEdits QuestionId (Result Errors.Error ())


update : String -> State -> Msg -> Response State Msg
update id_token state msg =
    case msg of
        AddNewQuestion id ->
            Response.state
                { state
                    | new_question =
                        Just
                            { category_id = id
                            , title = ""
                            , correct_answer = ""
                            , incorrect_answer_1 = ""
                            , incorrect_answer_2 = ""
                            , incorrect_answer_3 = ""
                            }
                }

        EditNewQuestionTitle s ->
            Response.state
                { state | new_question = Maybe.map (\q -> { q | title = s }) state.new_question }

        EditNewQuestionCorrectAnswer s ->
            Response.state
                { state
                    | new_question =
                        Maybe.map (\q -> { q | correct_answer = s }) state.new_question
                }

        EditNewQuestionIncorrectAnswer1 s ->
            Response.state
                { state
                    | new_question =
                        Maybe.map (\q -> { q | incorrect_answer_1 = s }) state.new_question
                }

        EditNewQuestionIncorrectAnswer2 s ->
            Response.state
                { state
                    | new_question =
                        Maybe.map (\q -> { q | incorrect_answer_2 = s }) state.new_question
                }

        EditNewQuestionIncorrectAnswer3 s ->
            Response.state
                { state
                    | new_question =
                        Maybe.map (\q -> { q | incorrect_answer_3 = s }) state.new_question
                }

        CancelNewQuestion ->
            Response.state { state | new_question = Nothing }

        SubmitNewQuestion ->
            case state.new_question of
                Just new_question ->
                    Response.http
                        state
                        id_token
                        "POST"
                        questionsUrl
                        (Http.jsonBody (newQuestionEncoder new_question))
                        (Errors.expectWhateverWithError SubmittedNewQuestion)

                Nothing ->
                    Response.state state

        SubmittedNewQuestion result ->
            case result of
                Ok _ ->
                    { state = { state | new_question = Nothing }
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest questionsUrl ]
                    , done = False
                    , reload = True
                    , errors = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest questionsUrl ]
                    , done = False
                    , reload = False
                    , errors = [ e ]
                    }

        RemoveQuestion id ->
            Response.http
                state
                id_token
                "DELETE"
                (questionUrl id)
                Http.emptyBody
                (Errors.expectWhateverWithError (RemovedQuestion id))

        RemovedQuestion id result ->
            case result of
                Ok _ ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest (questionUrl id) ]
                    , done = False
                    , reload = True
                    , errors = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest (questionUrl id) ]
                    , done = False
                    , reload = False
                    , errors = [ e ]
                    }

        EditTitle id s ->
            Response.state
                { state
                    | questions =
                        Dict.update id
                            (\q ->
                                case q of
                                    Just question ->
                                        Just { question | title = s }

                                    Nothing ->
                                        Just
                                            { title = s
                                            , correct_answer = Nothing
                                            , incorrect_answer_1 = Nothing
                                            , incorrect_answer_2 = Nothing
                                            , incorrect_answer_3 = Nothing
                                            }
                            )
                            state.questions
                }

        EditCorrectAnswer id s ->
            Response.state
                { state
                    | questions =
                        Dict.update id
                            (\q ->
                                case q of
                                    Just question ->
                                        Just { question | correct_answer = s }

                                    Nothing ->
                                        Just
                                            { title = Nothing
                                            , correct_answer = s
                                            , incorrect_answer_1 = Nothing
                                            , incorrect_answer_2 = Nothing
                                            , incorrect_answer_3 = Nothing
                                            }
                            )
                            state.questions
                }

        EditIncorrectAnswer1 id s ->
            Response.state
                { state
                    | questions =
                        Dict.update id
                            (\q ->
                                case q of
                                    Just question ->
                                        Just { question | incorrect_answer_1 = s }

                                    Nothing ->
                                        Just
                                            { title = Nothing
                                            , correct_answer = Nothing
                                            , incorrect_answer_1 = s
                                            , incorrect_answer_2 = Nothing
                                            , incorrect_answer_3 = Nothing
                                            }
                            )
                            state.questions
                }

        EditIncorrectAnswer2 id s ->
            Response.state
                { state
                    | questions =
                        Dict.update id
                            (\q ->
                                case q of
                                    Just question ->
                                        Just { question | incorrect_answer_2 = s }

                                    Nothing ->
                                        Just
                                            { title = Nothing
                                            , correct_answer = Nothing
                                            , incorrect_answer_1 = Nothing
                                            , incorrect_answer_2 = s
                                            , incorrect_answer_3 = Nothing
                                            }
                            )
                            state.questions
                }

        EditIncorrectAnswer3 id s ->
            Response.state
                { state
                    | questions =
                        Dict.update id
                            (\q ->
                                case q of
                                    Just question ->
                                        Just { question | incorrect_answer_3 = s }

                                    Nothing ->
                                        Just
                                            { title = Nothing
                                            , correct_answer = Nothing
                                            , incorrect_answer_1 = Nothing
                                            , incorrect_answer_2 = s
                                            , incorrect_answer_3 = Nothing
                                            }
                            )
                            state.questions
                }

        SubmitEdits id ->
            case Dict.get id state.questions of
                Just question ->
                    Response.http
                        { state | questions = Dict.remove id state.questions }
                        id_token
                        "PUT"
                        (questionUrl id)
                        (Http.jsonBody (partialQuestionEncoder question))
                        (Errors.expectWhateverWithError (SubmittedEdits id))

                Nothing ->
                    Response.state state

        SubmittedEdits id result ->
            case result of
                Ok _ ->
                    { state = { state | new_question = Nothing }
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest (questionUrl id) ]
                    , done = False
                    , reload = True
                    , errors = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest questionsUrl ]
                    , done = False
                    , reload = False
                    , errors = [ e ]
                    }


viewQuestion : Question -> PartialQuestion -> Html Msg
viewQuestion question edit_question =
    div [ class "box" ]
        [ div [ class "columns" ]
            [ p [ class "column subtitle is-5" ]
                [ Users.viewEditableText
                    question.title
                    edit_question.title
                    (\s -> EditTitle question.id (Just s))
                    (EditTitle question.id Nothing)
                ]
            , div [ class "column buttons" ]
                [ div [ class "buttons is-pulled-right" ]
                    [ button
                        [ class "button is-primary"
                        , onClick (SubmitEdits question.id)
                        ]
                        [ text "Submit" ]
                    , button
                        [ class "button is-pulled-right is-danger"
                        , onClick (RemoveQuestion question.id)
                        ]
                        [ text "Remove" ]
                    ]
                ]
            ]
        , Users.viewEditableText
            question.correct_answer
            edit_question.correct_answer
            (\s -> EditCorrectAnswer question.id (Just s))
            (EditCorrectAnswer question.id Nothing)
        , Users.viewEditableText
            question.incorrect_answer_1
            edit_question.incorrect_answer_1
            (\s -> EditIncorrectAnswer1 question.id (Just s))
            (EditIncorrectAnswer1 question.id Nothing)
        , Users.viewEditableText
            question.incorrect_answer_2
            edit_question.incorrect_answer_2
            (\s -> EditIncorrectAnswer2 question.id (Just s))
            (EditIncorrectAnswer2 question.id Nothing)
        , Users.viewEditableText
            question.incorrect_answer_3
            edit_question.incorrect_answer_3
            (\s -> EditIncorrectAnswer3 question.id (Just s))
            (EditIncorrectAnswer3 question.id Nothing)
        ]


viewCategoryDetail : Dict QuestionId Question -> State -> QuestionCategory -> Html Msg
viewCategoryDetail questions state category =
    div []
        [ p [ class "title" ] [ text category.title ]
        , div []
            ((Dict.toList questions
                |> List.filter (\( id, q ) -> q.category_id == category.id)
                |> List.map
                    (\( id, q ) ->
                        viewQuestion
                            q
                            (Maybe.withDefault
                                { title = Nothing
                                , correct_answer = Nothing
                                , incorrect_answer_1 = Nothing
                                , incorrect_answer_2 = Nothing
                                , incorrect_answer_3 = Nothing
                                }
                                (Dict.get id state.questions)
                            )
                    )
             )
                ++ [ case state.new_question of
                        Just new_question ->
                            div [ class "box" ]
                                [ div [ class "columns" ]
                                    [ input
                                        [ class "column subtitle is-5"
                                        , value new_question.title
                                        , onInput EditNewQuestionTitle
                                        ]
                                        []
                                    , div [ class "column buttons" ]
                                        [ div [ class "buttons is-pulled-right" ]
                                            [ button
                                                [ class "button is-primary"
                                                , onClick SubmitNewQuestion
                                                ]
                                                [ text "Submit" ]
                                            , button
                                                [ class "button is-danger"
                                                , onClick CancelNewQuestion
                                                ]
                                                [ text "Cancel" ]
                                            ]
                                        ]
                                    ]
                                , input
                                    [ class "input"
                                    , value new_question.correct_answer
                                    , onInput EditNewQuestionCorrectAnswer
                                    ]
                                    []
                                , input
                                    [ class "input"
                                    , value new_question.incorrect_answer_1
                                    , onInput EditNewQuestionIncorrectAnswer1
                                    ]
                                    []
                                , input
                                    [ class "input"
                                    , value new_question.incorrect_answer_2
                                    , onInput EditNewQuestionIncorrectAnswer2
                                    ]
                                    []
                                , input
                                    [ class "input"
                                    , value new_question.incorrect_answer_3
                                    , onInput EditNewQuestionIncorrectAnswer3
                                    ]
                                    []
                                ]

                        Nothing ->
                            button
                                [ class "button is-primary"
                                , onClick (AddNewQuestion category.id)
                                ]
                                [ text "New Question" ]
                   ]
            )
        ]


viewCategory : Dict QuestionId Question -> QuestionCategory -> Html msg
viewCategory questions category =
    a [ class "box", href (B.relative [ "question_categories", String.fromInt category.id ] []) ]
        [ div [ class "columns" ]
            [ p [ class "column title is-5" ] [ text category.title ]
            , p [ class "column is-pulled-right has-text-right" ]
                [ text
                    ((Dict.toList questions
                        |> List.filter (\( id, q ) -> q.category_id == category.id)
                        |> List.map (\( id, q ) -> viewQuestion q)
                        |> List.length
                        |> String.fromInt
                     )
                        ++ " questions"
                    )
                ]
            ]
        ]


viewCategories : Dict QuestionId Question -> Dict QuestionCategoryId QuestionCategory -> Html msg
viewCategories questions categories =
    div []
        [ p [ class "title has-text-centered" ] [ text "Question Categories" ]
        , div [ class "columns" ]
            [ div [ class "column is-one-fifth" ]
                [ p [ class "title is-4 has-text-centered" ] [ text "Search" ]
                , p [ class "has-text-centered" ] [ text "Working on it :)" ]
                ]
            , div [ class "column" ]
                [ div [] (List.map (viewCategory questions) (Dict.values categories))
                , a [ class "button is-primary", href "/question_categories/new" ]
                    [ text "New Question Category" ]
                ]
            ]
        ]


questionDecoder : Decode.Decoder Question
questionDecoder =
    Decode.map7 Question
        (Decode.field "id" Decode.int)
        (Decode.field "category_id" Decode.int)
        (Decode.field "title" Decode.string)
        (Decode.field "correct_answer" Decode.string)
        (Decode.field "incorrect_answer_1" Decode.string)
        (Decode.field "incorrect_answer_2" Decode.string)
        (Decode.field "incorrect_answer_3" Decode.string)


questionListDecoder : Decode.Decoder (List Question)
questionListDecoder =
    Decode.field "questions" (Decode.list questionDecoder)


newQuestionEncoder : NewQuestion -> Encode.Value
newQuestionEncoder question =
    Encode.object
        [ ( "category_id", Encode.int question.category_id )
        , ( "title", Encode.string question.title )
        , ( "correct_answer", Encode.string question.correct_answer )
        , ( "incorrect_answer_1", Encode.string question.incorrect_answer_1 )
        , ( "incorrect_answer_2", Encode.string question.incorrect_answer_2 )
        , ( "incorrect_answer_3", Encode.string question.incorrect_answer_3 )
        ]


partialQuestionEncoder : PartialQuestion -> Encode.Value
partialQuestionEncoder question =
    Encode.object
        ([]
            |> (\l ->
                    case question.title of
                        Just title ->
                            ( "title", Encode.string title ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case question.correct_answer of
                        Just correct_answer ->
                            ( "correct_answer", Encode.string correct_answer ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case question.incorrect_answer_1 of
                        Just incorrect_answer_1 ->
                            ( "incorrect_answer_1", Encode.string incorrect_answer_1 ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case question.incorrect_answer_2 of
                        Just incorrect_answer_2 ->
                            ( "incorrect_answer_2", Encode.string incorrect_answer_2 ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case question.incorrect_answer_3 of
                        Just incorrect_answer_3 ->
                            ( "incorrect_answer_3", Encode.string incorrect_answer_3 ) :: l

                        Nothing ->
                            l
               )
        )
