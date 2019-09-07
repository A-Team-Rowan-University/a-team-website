module Tests.List exposing
    ( Id
    , QuestionCategory
    , QuestionCategoryId
    , Test
    , listDecoder
    , manyUrl
    , questionCategoriesUrl
    , questionCategoryListDecoder
    , viewList
    )

import Config exposing (..)
import Dict exposing (Dict)
import Html exposing (Html, a, div, p, span, text)
import Html.Attributes exposing (class, href)
import Json.Decode as Decode
import Url.Builder as B
import Users.Users as User


manyUrl : String
manyUrl =
    B.relative [ apiUrl, "tests/" ] []


questionCategoriesUrl : String
questionCategoriesUrl =
    B.relative [ apiUrl, "question_categories/" ] []


type alias QuestionCategoryId =
    Int


type alias Id =
    Int


type alias QuestionCategory =
    { id : QuestionCategoryId
    , title : String
    }


type alias Test =
    { id : Id
    , creator : User.Id
    , name : String
    , questions : List ( QuestionCategoryId, Int )
    }


view : Dict User.Id User.User -> Test -> Html msg
view users test =
    a
        [ class "box"
        , href (B.relative [ "tests", String.fromInt test.id ] [])
        ]
        [ p [ class "title is-5" ]
            [ text test.name ]
        , p [ class "subtitle is-5 columns" ]
            [ span [ class "column" ]
                [ text
                    (Dict.get test.creator users
                        |> Maybe.map
                            (\u -> "Created by " ++ u.first_name ++ " " ++ u.last_name)
                        |> Maybe.withDefault "Unknown User"
                    )
                ]
            ]
        ]


viewList : Dict User.Id User.User -> Dict Id Test -> Html msg
viewList users tests =
    div []
        [ p [ class "title has-text-centered" ] [ text "Tests" ]
        , div [ class "columns" ]
            [ div [ class "column is-one-fifth" ]
                [ p [ class "title is-4 has-text-centered" ] [ text "Search" ]
                , p [ class "has-text-centered" ] [ text "Working on it :)" ]
                ]
            , div [ class "column" ]
                [ div [] (List.map (view users) (Dict.values tests))
                , a [ class "button is-primary", href "/tests/new" ] [ text "New Test" ]
                ]
            ]
        ]


questionCategoryDecoder : Decode.Decoder QuestionCategory
questionCategoryDecoder =
    Decode.map2 QuestionCategory
        (Decode.field "id" Decode.int)
        (Decode.field "title" Decode.string)


questionCategoryListDecoder : Decode.Decoder (List QuestionCategory)
questionCategoryListDecoder =
    Decode.field "question_categories" (Decode.list questionCategoryDecoder)


decoder : Decode.Decoder Test
decoder =
    Decode.map4 Test
        (Decode.field "id" Decode.int)
        (Decode.field "creator_id" Decode.int)
        (Decode.field "name" Decode.string)
        (Decode.field "questions"
            (Decode.list
                (Decode.map2
                    Tuple.pair
                    (Decode.field "question_category_id" Decode.int)
                    (Decode.field "number_of_questions" Decode.int)
                )
            )
        )


listDecoder : Decode.Decoder (List Test)
listDecoder =
    Decode.field "tests" (Decode.list decoder)
