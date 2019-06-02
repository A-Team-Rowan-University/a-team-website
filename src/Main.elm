port module Main exposing (Model, Msg(..), init, main, subscriptions, update, view)

import Browser
import Html exposing (Html, a, button, div, h1, img, input, nav, pre, span, text)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http exposing (emptyBody, header)
import Json.Decode exposing (Decoder, decodeValue, field, int, list, map5, nullable, string)
import Json.Encode as E
import Platform.Cmd
import Platform.Sub
import SignIn exposing (SignInModel(..), SignInMsg, SignInUser, signInSubscriptions, updateSignIn, viewSignIn)


main =
    Browser.element
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map GotSignInMsg (signInSubscriptions model.signin)



-- MODEL


type alias User =
    { id : Int
    , first_name : String
    , last_name : String
    , email : Maybe String
    , banner_id : Int
    }


type UserListModel
    = Loading
    | UserList (List User)
    | NetworkError Http.Error


type PageModel
    = PageUserList UserListModel
    | PageHome


type alias Model =
    { signin : SignInModel
    , page : PageModel
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { signin = SignedOut
      , page = PageHome
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = GotSignInMsg SignInMsg
    | GotUsers (Result Http.Error (List User))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSignInMsg signin_msg ->
            let
                ( signInModel, signInCmd ) =
                    updateSignIn signin_msg model.signin
            in
            ( { model | signin = signInModel }, Cmd.map GotSignInMsg signInCmd )

        GotUsers users_result ->
            ( case users_result of
                Ok users ->
                    { model | page = PageUserList (UserList users) }

                Err e ->
                    { model | page = PageUserList (NetworkError e) }
            , Cmd.none
            )


userDecoder : Decoder User
userDecoder =
    map5 User
        (field "id" int)
        (field "first_name" string)
        (field "last_name" string)
        (field "email" (nullable string))
        (field "banner_id" int)


userListDecoder : Decoder (List User)
userListDecoder =
    field "users" (list userDecoder)



-- VIEW


viewUser : User -> Html Msg
viewUser user =
    div []
        [ div [] [ text (user.first_name ++ " " ++ user.last_name) ]
        , div [] [ text (Maybe.withDefault "No email" user.email) ]
        , div [] [ text (String.fromInt user.banner_id) ]
        ]


viewPageUserList : UserListModel -> Html Msg
viewPageUserList user_list =
    case user_list of
        Loading ->
            text "Loading users..."

        UserList users ->
            div [] (List.map viewUser users)

        NetworkError e ->
            text "Network error loading users!"


viewPage : PageModel -> Html Msg
viewPage page =
    case page of
        PageUserList user_list ->
            viewPageUserList user_list

        PageHome ->
            h1 [] [ text "Welcome to the A-Team!" ]


view : Model -> Html Msg
view model =
    div []
        [ nav [ class "navbar", class "is-primary" ]
            [ div [ class "navbar-brand" ]
                [ a [ class "navbar-item", href "/" ]
                    [ img [ src "/A-TeamLogo2.svg" ] [] ]
                , a
                    [ attribute "role" "button"
                    , class "navbar-burger"
                    , class "burger"
                    , attribute "aria-label" "menu"
                    , attribute "aria-expanded" "false"
                    , attribute "data-target" "navbar"
                    ]
                    [ span [ attribute "aria-hidden" "true" ] []
                    , span [ attribute "aria-hidden" "true" ] []
                    , span [ attribute "aria-hidden" "true" ] []
                    ]
                ]
            , div [ id "navbar", class "navbar-menu" ]
                [ div [ class "navbar-start" ]
                    [ a [ class "navbar-item" ] [ text "Home" ]
                    , a [ class "navbar-item" ] [ text "Users" ]
                    ]
                , div [ class "navbar-end" ]
                    [ div [ class "navbar-item" ]
                        [ Html.map GotSignInMsg (viewSignIn model.signin) ]
                    ]
                ]
            ]
        , viewPage model.page
        ]



--
