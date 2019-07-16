module Tests.New exposing (Msg, NewTest, Response, State, init, update, view)

import Dict exposing (Dict)
import Html exposing (Html, a, button, div, input, p, span, text)
import Html.Attributes exposing (class, type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Encode
import Network exposing (Notification(..), RequestChange(..))
import Tests.List exposing (QuestionCategory, QuestionCategoryId)


type alias NewTest r =
    { r
        | name : String
        , questions : Dict QuestionCategoryId Int
    }


type alias State =
    { name : String
    , questions : Dict QuestionCategoryId Int
    }


init : State
init =
    { name = ""
    , questions = Dict.empty
    }


type Msg
    = EditName String
    | EditQuestion QuestionCategoryId (Maybe Int)
    | Submit
    | Submitted (Result Http.Error ())


type alias Response =
    { state : State
    , cmd : Cmd Msg
    , requests : List RequestChange
    , done : Bool
    , notifications : List Notification
    }


update : String -> State -> Msg -> Response
update id_token state msg =
    case msg of
        EditName name ->
            { state = { state | name = name }
            , cmd = Cmd.none
            , requests = []
            , done = False
            , notifications = []
            }

        EditQuestion question_category_id maybe_number_of_questions ->
            case maybe_number_of_questions of
                Just number_of_questions ->
                    let
                        questions =
                            state.questions
                    in
                    { state =
                        { state
                            | questions =
                                if number_of_questions == 0 then
                                    Dict.remove
                                        question_category_id
                                        questions

                                else
                                    Dict.insert
                                        question_category_id
                                        number_of_questions
                                        questions
                        }
                    , cmd = Cmd.none
                    , requests = []
                    , done = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = []
                    , done = False
                    , notifications = []
                    }

        Submit ->
            { state = state
            , cmd =
                Http.request
                    { method = "POST"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = Tests.List.manyUrl
                    , body = Http.jsonBody (newEncoder state)
                    , expect = Http.expectWhatever Submitted
                    , timeout = Nothing
                    , tracker = Just Tests.List.manyUrl
                    }
            , requests = [ AddRequest Tests.List.manyUrl ]
            , done = False
            , notifications = []
            }

        Submitted result ->
            case result of
                Ok _ ->
                    { state = init
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest Tests.List.manyUrl ]
                    , done = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ RemoveRequest Tests.List.manyUrl ]
                    , done = False
                    , notifications = []
                    }


view : Dict QuestionCategoryId QuestionCategory -> State -> Html Msg
view question_categories state =
    div []
        [ p [ class "title has-text-centered" ]
            [ text "New Test" ]
        , p [ class "columns" ]
            [ span [ class "column" ]
                [ p [ class "subtitle has-text-centered" ]
                    [ text "Test Details" ]
                , div [ class "box" ]
                    [ span [] [ text "Name: " ]
                    , input
                        [ class "input"
                        , value state.name
                        , onInput EditName
                        ]
                        []
                    ]
                , button
                    [ class "button is-primary"
                    , onClick Submit
                    ]
                    [ text "Submit new test" ]
                ]
            , div [ class "column" ]
                [ p [ class "subtitle has-text-centered" ]
                    [ text "Test Questions" ]
                , viewTestQuestionCategories
                    EditQuestion
                    question_categories
                    state.questions
                ]
            ]
        ]


viewTestQuestionCategories :
    (QuestionCategoryId -> Maybe Int -> msg)
    -> Dict QuestionCategoryId QuestionCategory
    -> Dict QuestionCategoryId Int
    -> Html msg
viewTestQuestionCategories onEdit question_categories questions =
    div [ class "box" ]
        (List.map
            (\( question_category_id, question_category ) ->
                viewTestQuestionCategory
                    (onEdit question_category_id)
                    ( question_category
                    , Maybe.withDefault 0
                        (Dict.get question_category_id questions)
                    )
            )
            (Dict.toList
                question_categories
            )
        )


viewTestQuestionCategory :
    (Maybe Int -> msg)
    -> ( QuestionCategory, Int )
    -> Html msg
viewTestQuestionCategory onEdit ( question_category, number_of_questions ) =
    div [ class "columns" ]
        [ span [ class "column" ]
            [ text question_category.title ]
        , div [ class "column" ]
            [ input
                [ class "input"
                , type_ "number"
                , value (String.fromInt number_of_questions)
                , onInput
                    (\s -> onEdit (String.toInt s))
                ]
                []
            ]
        ]


questionCategoryEncoder : ( QuestionCategoryId, Int ) -> Json.Encode.Value
questionCategoryEncoder ( question_category_id, number_of_questions ) =
    Json.Encode.object
        [ ( "question_category_id", Json.Encode.int question_category_id )
        , ( "number_of_questions", Json.Encode.int number_of_questions )
        ]


newEncoder : NewTest r -> Json.Encode.Value
newEncoder test =
    Json.Encode.object
        [ ( "name", Json.Encode.string test.name )
        , ( "questions"
          , Json.Encode.list questionCategoryEncoder
                (test.questions |> Dict.toList)
          )
        ]
