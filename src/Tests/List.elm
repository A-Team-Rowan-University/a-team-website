module Tests.List exposing (Id, QuestionCategory, QuestionCategoryId, Test)

import Json.Decode as Decode
import Users.Users as User


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
    , questions : ( QuestionCategoryId, Int )
    }


questionCategoryDecoder : Decode.Decoder QuestionCategory
questionCategoryDecoder =
    Decode.map2 QuestionCategory
        (Decode.field "id" Decode.int)
        (Decode.field "title" Decode.string)


decoder : Decode.Decoder Test
decoder =
    Decode.map4 Test
        (Decode.field "id" Decode.int)
        (Decode.field "creator" Decode.int)
        (Decode.field "name" Decode.string)
        (Decode.field "questions"
            (Decode.map2
                Tuple.pair
                (Decode.field "question_category_id" Decode.int)
                (Decode.field "number_of_questions" Decode.int)
            )
        )
