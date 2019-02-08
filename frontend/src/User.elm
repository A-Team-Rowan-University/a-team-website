module User exposing (UserModel, UserMsg, init, update, view)

import Debug
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (usLocale)
import Html exposing (Attribute, Html, div, h1, input, table, td, text, tr, ul)
import Html.Attributes exposing (checked, type_, value)
import Html.Events exposing (onCheck, onClick, onInput)
import Http
import Json.Decode as Decode exposing (Decoder, field, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import Url.Builder exposing (crossOrigin)


type alias UserModel =
    { user_list : Result Http.Error UserList
    , first_name_search : Maybe String
    , last_name_search : Maybe String
    , banner_id_search : Maybe Int
    , email_null_search : Bool
    , email_search : Maybe String
    , create_user : Maybe CreateUser
    }


type UserMsg
    = GotUsers (Result Http.Error UserList)
    | SearchFirstName String
    | SearchLastName String
    | SearchBannerId String
    | SearchNullEmail Bool
    | SearchEmail String
    | DeleteUser Int
    | UserDeleted (Result Http.Error ())
    | ShowCreateUser ()
    | CreateUserFirstName String
    | CreateUserLastName String
    | CreateUserBannerId String
    | CreateUserHasEmail Bool
    | CreateUserEmail String
    | SubmitCreateUser ()
    | SubmittedCreateUser (Result Http.Error ())


type alias User =
    { id : Int
    , first_name : String
    , last_name : String
    , banner_id : Int
    , email : Maybe String
    }


type alias CreateUser =
    { first_name : String
    , last_name : String
    , banner_id : Maybe Int
    , email : Maybe String
    }


type alias UserList =
    List User


init : () -> ( UserModel, Cmd UserMsg )
init _ =
    ( { user_list = Ok []
      , first_name_search = Nothing
      , last_name_search = Nothing
      , banner_id_search = Nothing
      , email_null_search = False
      , email_search = Nothing
      , create_user = Nothing
      }
    , Http.get
        { url = "http://localhost:8000/users/"
        , expect = Http.expectJson GotUsers decodeUserList
        }
    )


update : UserMsg -> UserModel -> ( UserModel, Cmd UserMsg )
update msg model =
    case msg of
        GotUsers result ->
            case result of
                Ok users ->
                    ( { model | user_list = Ok users }, Cmd.none )

                Err error ->
                    ( { model | user_list = Err error }, Cmd.none )

        SearchFirstName first_name ->
            let
                new_model =
                    { model | first_name_search = emptyToNothing first_name }
            in
            ( new_model, searchCmd new_model )

        SearchLastName last_name ->
            let
                new_model =
                    { model | last_name_search = emptyToNothing last_name }
            in
            ( new_model, searchCmd new_model )

        SearchBannerId banner_id ->
            let
                new_model =
                    { model | banner_id_search = emptyToNothingInt banner_id }
            in
            ( new_model, searchCmd new_model )

        SearchNullEmail null_email ->
            let
                new_model =
                    { model | email_null_search = null_email }
            in
            ( new_model, searchCmd new_model )

        SearchEmail email ->
            let
                new_model =
                    { model | email_search = emptyToNothing email }
            in
            ( new_model, searchCmd new_model )

        DeleteUser id ->
            ( model, deleteCmd id )

        UserDeleted err ->
            ( model, searchCmd model )

        ShowCreateUser _ ->
            ( { model | create_user = Just emptyCreateUser }, Cmd.none )

        CreateUserFirstName first_name ->
            case model.create_user of
                Just create_user ->
                    let
                        new_create_user =
                            { create_user | first_name = first_name }
                    in
                    ( { model | create_user = Just new_create_user }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        CreateUserLastName last_name ->
            case model.create_user of
                Just create_user ->
                    let
                        new_create_user =
                            { create_user | last_name = last_name }
                    in
                    ( { model | create_user = Just new_create_user }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        CreateUserBannerId banner_id ->
            case model.create_user of
                Just create_user ->
                    let
                        new_create_user =
                            { create_user | banner_id = emptyToNothingInt banner_id }
                    in
                    ( { model | create_user = Just new_create_user }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        CreateUserHasEmail has_email ->
            case model.create_user of
                Just create_user ->
                    let
                        new_create_user =
                            { create_user
                                | email =
                                    if has_email then
                                        Just ""

                                    else
                                        Nothing
                            }
                    in
                    ( { model | create_user = Just new_create_user }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        CreateUserEmail email ->
            case model.create_user of
                Just create_user ->
                    let
                        new_create_user =
                            { create_user | email = Just email }
                    in
                    ( { model | create_user = Just new_create_user }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SubmitCreateUser _ ->
            case model.create_user of
                Just create_user ->
                    ( { model | create_user = Nothing }, createCmd create_user )

                Nothing ->
                    ( model, Cmd.none )

        SubmittedCreateUser err ->
            ( model, searchCmd model )


createCmd : CreateUser -> Cmd UserMsg
createCmd create_user =
    case create_user.banner_id of
        Just banner_id ->
            let
                user_body =
                    Encode.object
                        [ ( "first_name", Encode.string create_user.first_name )
                        , ( "last_name", Encode.string create_user.last_name )
                        , ( "banner_id", Encode.int banner_id )
                        , ( "email"
                          , case create_user.email of
                                Just email ->
                                    Encode.string email

                                Nothing ->
                                    Encode.null
                          )
                        ]
            in
            Http.post
                { url = "http://localhost:8000/users/"
                , body = Http.jsonBody user_body
                , expect = Http.expectWhatever SubmittedCreateUser
                }

        Nothing ->
            Cmd.none


emptyCreateUser : CreateUser
emptyCreateUser =
    { first_name = ""
    , last_name = ""
    , banner_id = Nothing
    , email = Nothing
    }


emptyToNothingInt : String -> Maybe Int
emptyToNothingInt s =
    if String.isEmpty s then
        Nothing

    else
        String.toInt s


emptyToNothing : String -> Maybe String
emptyToNothing s =
    if String.isEmpty s then
        Nothing

    else
        Just s


deleteCmd : Int -> Cmd UserMsg
deleteCmd id =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = crossOrigin "http://localhost:8000" [ "users", String.fromInt id ] []
        , body = Http.emptyBody
        , expect = Http.expectWhatever UserDeleted
        , timeout = Nothing
        , tracker = Nothing
        }


searchCmd : UserModel -> Cmd UserMsg
searchCmd model =
    Http.get
        { url =
            crossOrigin "http://localhost:8000"
                [ "users/" ]
                ([]
                    |> concatConditional
                        (Maybe.map (\a -> Url.Builder.string "first_name_exact" a) model.first_name_search)
                    |> concatConditional
                        (Maybe.map (\a -> Url.Builder.string "last_name_exact" a) model.last_name_search)
                    |> concatConditional
                        (Maybe.map (\a -> Url.Builder.int "banner_id_exact" a) model.banner_id_search)
                    |> concatConditional (hasEmailQuery model.email_search model.email_null_search)
                    |> concatConditional (emailQuery model.email_search model.email_null_search)
                )
        , expect = Http.expectJson GotUsers decodeUserList
        }


hasEmailQuery : Maybe String -> Bool -> Maybe Url.Builder.QueryParameter
hasEmailQuery email_search email_null_search =
    case ( email_search, email_null_search ) of
        ( Nothing, False ) ->
            Nothing

        ( Nothing, True ) ->
            Just (Url.Builder.string "has_email" "false")

        ( Just _, False ) ->
            Just (Url.Builder.string "has_email" "true")

        ( Just _, True ) ->
            Just (Url.Builder.string "has_email" "false")


emailQuery : Maybe String -> Bool -> Maybe Url.Builder.QueryParameter
emailQuery email_search email_null_search =
    case ( email_search, email_null_search ) of
        ( Nothing, False ) ->
            Nothing

        ( Nothing, True ) ->
            Nothing

        ( Just s, False ) ->
            Just (Url.Builder.string "email_exact" s)

        ( Just _, True ) ->
            Nothing


concatConditional : Maybe a -> List a -> List a
concatConditional m l =
    case m of
        Just value ->
            l ++ [ value ]

        Nothing ->
            l


view : UserModel -> Html UserMsg
view model =
    div []
        [ h1 [] [ text "Users" ]
        , div []
            [ input
                [ type_ "text"
                , value (Maybe.withDefault "" model.first_name_search)
                , onInput SearchFirstName
                ]
                []
            , input
                [ type_ "text"
                , value (Maybe.withDefault "" model.last_name_search)
                , onInput SearchLastName
                ]
                []
            , input
                [ type_ "text"
                , value (Maybe.withDefault "" (Maybe.map String.fromInt model.banner_id_search))
                , onInput SearchBannerId
                ]
                []
            , input
                [ type_ "text"
                , value (Maybe.withDefault "" model.email_search)
                , onInput SearchEmail
                ]
                []
            , input
                [ type_ "checkbox"
                , checked model.email_null_search
                , onCheck SearchNullEmail
                ]
                []
            ]
        , case model.user_list of
            Ok user_list ->
                viewUsers user_list

            Err error ->
                viewHttpError error
        , case model.create_user of
            Nothing ->
                input [ type_ "button", value "Add User", onClick (ShowCreateUser ()) ] []

            Just create_user ->
                viewCreateUser create_user
        ]


viewCreateUser : CreateUser -> Html UserMsg
viewCreateUser create_user =
    div []
        (([ input
                [ type_ "text"
                , value create_user.first_name
                , onInput CreateUserFirstName
                ]
                []
          , input
                [ type_ "text"
                , value create_user.last_name
                , onInput CreateUserLastName
                ]
                []
          , input
                [ type_ "text"
                , value (Maybe.withDefault "" (Maybe.map String.fromInt create_user.banner_id))
                , onInput CreateUserBannerId
                ]
                []
          , div []
                [ text "Has email?"
                , input
                    [ type_ "checkbox"
                    , checked
                        (case create_user.email of
                            Just _ ->
                                True

                            Nothing ->
                                False
                        )
                    , onCheck CreateUserHasEmail
                    ]
                    []
                ]
          ]
            |> concatConditional
                (Maybe.map
                    (\email -> input [ type_ "text", value email, onInput CreateUserEmail ] [])
                    create_user.email
                )
         )
            ++ [ input
                    [ type_ "button"
                    , value "Submit User"
                    , onClick (SubmitCreateUser ())
                    ]
                    []
               ]
        )


viewUsers : List User -> Html UserMsg
viewUsers users =
    table [] (List.map viewUserRow users)


viewUserRow : User -> Html UserMsg
viewUserRow user =
    tr []
        [ td [] [ text user.first_name ]
        , td [] [ text user.last_name ]
        , td [] [ text (String.fromInt user.banner_id) ]
        , td []
            [ case user.email of
                Just email ->
                    text email

                Nothing ->
                    text "No email"
            ]
        , td [] [ input [ type_ "button", value "Delete", onClick (DeleteUser user.id) ] [] ]
        ]


viewHttpError : Http.Error -> Html UserMsg
viewHttpError error =
    case error of
        Http.BadUrl string ->
            text string

        Http.Timeout ->
            text "Timeout!"

        Http.NetworkError ->
            text "Network error!"

        Http.BadStatus status ->
            text (format usLocale (toFloat status))

        Http.BadBody body ->
            text body


decodeUserList : Decoder (List User)
decodeUserList =
    field "users" (list decodeUser)


decodeUser : Decoder User
decodeUser =
    Decode.succeed User
        |> required "id" int
        |> required "first_name" string
        |> required "last_name" string
        |> required "banner_id" int
        |> required "email" (nullable string)
