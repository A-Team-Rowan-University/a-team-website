port module Main exposing (Model, Msg(..), init, main, subscriptions, update, view)

import Browser
import Browser.Navigation as Nav
import Config exposing (..)
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http exposing (Progress, emptyBody, header, jsonBody)
import Json.Decode as D
import Json.Encode as E
import Network exposing (..)
import Platform.Cmd
import Platform.Sub
import Session exposing (Session, googleUserDecoder, idToken)
import Set exposing (Set)
import Url
import Url.Builder as B
import Url.Parser as P exposing ((</>))
import Users exposing (User)


main =
    Browser.application
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    signIn SignedIn



-- Ports


port signIn : (E.Value -> msg) -> Sub msg



-- MODEL


type Route
    = Home
    | Users
    | UserDetail Int
    | UserNew
    | NotFound


routeParser : P.Parser (Route -> a) a
routeParser =
    P.oneOf
        [ P.map Home P.top
        , P.map Users (P.s "users")
        , P.map UserDetail (P.s "users" </> P.int)
        , P.map UserNew (P.s "users" </> P.s "new")
        ]


type alias Model =
    { navkey : Nav.Key
    , route : Route
    , session : Session Users.Id
    , users : Dict Users.Id User
    , users_status : Network ()
    , user_detail : Users.DetailState
    , user_new : Users.New
    , user_new_access : Maybe Int
    , requests : Set String
    , notifications : List Notification
    }


handleRequestChange : Maybe RequestChange -> Set String -> Set String
handleRequestChange request requests =
    case request of
        Just (AddRequest r) ->
            Set.insert r requests

        Just (RemoveRequest r) ->
            Set.remove r requests

        Nothing ->
            requests


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { navkey = key
      , route = Maybe.withDefault NotFound (P.parse routeParser url)
      , session = Session.NotSignedIn
      , users = Dict.empty
      , users_status = Loading Nothing
      , user_detail = Users.initDetail
      , user_new =
            { first_name = ""
            , last_name = ""
            , banner_id = 0
            , email = ""
            , accesses = []
            }
      , user_new_access = Nothing
      , requests = Set.empty
      , notifications = []
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = SignedIn E.Value
    | Validated (Result Http.Error User)
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotUsers (Result Http.Error (List User))
    | GotUser (Result Http.Error User)
    | UserDetailMsg Users.DetailMsg
    | Updated (Result Http.Error ())
    | NewFirstName String
    | NewLastName String
    | NewBannerId (Maybe Int)
    | NewEmail String
    | EditNewUserAccess (Maybe Int)
    | SubmitNewUserAccess
    | RemoveNewUserAccess Int
    | SubmitNewUser


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SignedIn user_json ->
            case D.decodeValue googleUserDecoder user_json of
                Ok google_user ->
                    ( { model
                        | session = Session.SignedIn google_user
                        , users_status = Loading Nothing
                      }
                    , Http.request
                        { method = "GET"
                        , headers = [ header "id_token" google_user.id_token ]
                        , url =
                            B.relative [ apiUrl, "users", "current" ]
                                []
                        , body = emptyBody
                        , expect = Http.expectJson Validated Users.decoder
                        , timeout = Nothing
                        , tracker = Nothing
                        }
                    )

                Err e ->
                    ( { model | session = Session.GoogleError e }, Cmd.none )

        Validated user_result ->
            case model.session of
                Session.SignedIn google_user ->
                    case user_result of
                        Ok user ->
                            let
                                session =
                                    Session.Validated user.id google_user

                                ( cmd, request, notifications ) =
                                    loadData session model.route
                            in
                            ( { model
                                | session = session
                                , users = Dict.insert user.id user model.users
                                , requests =
                                    handleRequestChange
                                        request
                                        model.requests
                                , notifications =
                                    model.notifications ++ notifications
                              }
                            , cmd
                            )

                        Err e ->
                            ( { model | session = Session.NetworkError e }
                            , Cmd.none
                            )

                _ ->
                    ( model, Cmd.none )

        GotUsers users_result ->
            ( case users_result of
                Ok users ->
                    { model
                        | users =
                            Dict.fromList
                                (List.map (\u -> ( u.id, u )) users)
                        , users_status = Loaded ()
                    }

                Err e ->
                    { model | users_status = NetworkError e }
            , Cmd.none
            )

        GotUser user_result ->
            ( case user_result of
                Ok user ->
                    { model
                        | users = Dict.insert user.id user model.users
                        , users_status = Loaded ()
                    }

                Err e ->
                    { model | users_status = NetworkError e }
            , Cmd.none
            )

        UserDetailMsg detail_msg ->
            case ( model.route, idToken model.session ) of
                ( UserDetail id, Just id_token ) ->
                    -- TODO Make this prettier
                    let
                        response =
                            Users.updateDetail
                                id_token
                                model.user_detail
                                detail_msg
                                id

                        ( cmd, requests, notifications ) =
                            if response.reload then
                                let
                                    ( load_cmd, load_request, load_notifications ) =
                                        loadData
                                            model.session
                                            model.route
                                in
                                ( Cmd.batch
                                    [ Cmd.map UserDetailMsg response.cmd
                                    , load_cmd
                                    ]
                                , model.requests
                                    |> handleRequestChange
                                        response.request
                                    |> handleRequestChange
                                        load_request
                                , response.notifications
                                    ++ load_notifications
                                )

                            else
                                ( Cmd.map UserDetailMsg response.cmd
                                , handleRequestChange
                                    response.request
                                    model.requests
                                , response.notifications
                                )
                    in
                    ( { model
                        | user_detail = response.state
                        , requests = requests
                        , notifications =
                            model.notifications
                                ++ notifications
                      }
                    , cmd
                    )

                _ ->
                    ( model, Cmd.none )

        Updated _ ->
            let
                ( cmd, request, notifications ) =
                    loadData model.session model.route
            in
            ( { model
                | requests =
                    handleRequestChange
                        request
                        model.requests
                , notifications =
                    model.notifications ++ notifications
              }
            , cmd
            )

        NewFirstName first_name ->
            let
                new_user =
                    model.user_new
            in
            ( { model
                | user_new =
                    { new_user | first_name = first_name }
              }
            , Cmd.none
            )

        NewLastName last_name ->
            let
                new_user =
                    model.user_new
            in
            ( { model | user_new = { new_user | last_name = last_name } }, Cmd.none )

        NewBannerId banner_id ->
            case banner_id of
                Just id ->
                    let
                        new_user =
                            model.user_new
                    in
                    ( { model | user_new = { new_user | banner_id = id } }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        NewEmail email ->
            let
                new_user =
                    model.user_new
            in
            ( { model | user_new = { new_user | email = email } }, Cmd.none )

        EditNewUserAccess access_id ->
            case access_id of
                Just id ->
                    ( { model | user_new_access = Just id }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SubmitNewUserAccess ->
            case model.user_new_access of
                Just access_id ->
                    let
                        new_user =
                            model.user_new
                    in
                    ( { model
                        | user_new =
                            { new_user | accesses = new_user.accesses ++ [ access_id ] }
                        , user_new_access = Nothing
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        RemoveNewUserAccess access_id ->
            let
                new_user =
                    model.user_new

                accesses =
                    new_user.accesses
            in
            ( { model | user_new = { new_user | accesses = List.filter (\id -> id /= access_id) accesses } }
            , Cmd.none
            )

        SubmitNewUser ->
            ( { model
                | user_new = Users.New "" "" 0 "" []
                , users_status = Loading Nothing
              }
            , case idToken model.session of
                Just id_token ->
                    case model.route of
                        UserNew ->
                            Cmd.batch
                                [ Http.request
                                    { method = "POST"
                                    , headers = [ header "id_token" id_token ]
                                    , url =
                                        B.relative
                                            [ apiUrl
                                            , "users/"
                                            ]
                                            []
                                    , body = jsonBody (Users.newEncoder model.user_new)
                                    , expect = Http.expectWhatever Updated
                                    , timeout = Nothing
                                    , tracker = Nothing
                                    }
                                , Nav.pushUrl model.navkey "/users"
                                ]

                        _ ->
                            Cmd.none

                _ ->
                    Cmd.none
            )

        LinkClicked request ->
            case request of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.navkey (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            case P.parse routeParser url of
                Nothing ->
                    ( { model | route = NotFound }, Cmd.none )

                Just route ->
                    let
                        ( cmd, request, notifications ) =
                            loadData model.session route
                    in
                    ( { model
                        | route = route
                        , requests =
                            handleRequestChange
                                request
                                model.requests
                        , notifications =
                            model.notifications ++ notifications
                      }
                    , cmd
                    )


loadData :
    Session Users.Id
    -> Route
    -> ( Cmd Msg, Maybe RequestChange, List Notification )
loadData session route =
    case route of
        Home ->
            ( Cmd.none, Nothing, [] )

        Users ->
            case idToken session of
                Just id_token ->
                    let
                        tracker =
                            "get users"
                    in
                    ( Http.request
                        { method = "GET"
                        , headers = [ header "id_token" id_token ]
                        , url = B.relative [ apiUrl, "users/" ] []
                        , body = emptyBody
                        , expect = Http.expectJson GotUsers Users.listDecoder
                        , timeout = Nothing
                        , tracker = Just tracker
                        }
                    , Just (AddRequest tracker)
                    , []
                    )

                Nothing ->
                    ( Cmd.none
                    , Nothing
                    , [ NWarning "You must be logged in to get users" ]
                    )

        UserDetail user_id ->
            case idToken session of
                Just id_token ->
                    let
                        tracker =
                            "get user " ++ String.fromInt user_id
                    in
                    ( Http.request
                        { method = "GET"
                        , headers = [ header "id_token" id_token ]
                        , url =
                            B.relative [ apiUrl, "users", String.fromInt user_id ]
                                []
                        , body = emptyBody
                        , expect = Http.expectJson GotUser Users.decoder
                        , timeout = Nothing
                        , tracker = Just tracker
                        }
                    , Just (AddRequest tracker)
                    , []
                    )

                Nothing ->
                    ( Cmd.none
                    , Nothing
                    , [ NWarning "You must be logged in to get users" ]
                    )

        UserNew ->
            ( Cmd.none, Nothing, [] )

        NotFound ->
            ( Cmd.none, Nothing, [] )



-- VIEW
{-
   | NewFirstName String
   | NewLastName String
   | NewBannerId (Maybe Int)
   | NewEmail String
   | EditNewUserAccess (Maybe Int)
   | SubmitNewUserAccess
   | RemoveNewUserAccess Int
   | SubmitNewUser
-}


newUserConfig : Users.NewConfig Msg
newUserConfig =
    { onEditFirstName = NewFirstName
    , onEditLastName = NewLastName
    , onEditEmail = NewEmail
    , onEditBannerId = NewBannerId
    , onEditAccess = EditNewUserAccess
    , onAddAccess = SubmitNewUserAccess
    , onRemoveAccess = RemoveNewUserAccess
    , onSubmit = SubmitNewUser
    }


viewPage : Model -> Html Msg
viewPage model =
    case model.route of
        Users ->
            Users.viewList model.users model.users_status

        UserDetail user_id ->
            case Dict.get user_id model.users of
                Just user ->
                    Html.map
                        UserDetailMsg
                        (Users.viewDetail
                            user
                            model.user_detail
                            model.users_status
                        )

                Nothing ->
                    p [] [ text "User not found" ]

        UserNew ->
            Users.viewNew
                newUserConfig
                model.user_new
                model.user_new_access

        Home ->
            h1 [] [ text "Welcome to the A-Team!" ]

        NotFound ->
            h1 [] [ text "Page not found!" ]


viewSession : Session Users.Id -> Dict Users.Id User -> Html msg
viewSession model users =
    case model of
        Session.Validated user_id google_user ->
            case Dict.get user_id users of
                Just user ->
                    viewValidated user google_user

                Nothing ->
                    div [] [ text "User not found!" ]

        Session.SignedIn google_iser ->
            div [] [ text "Validating..." ]

        Session.NotSignedIn ->
            div []
                [ div []
                    [ div
                        [ class "g-signin2"
                        , attribute "data-onsuccess" "onSignIn"
                        ]
                        [ text "Waiting for Google..." ]
                    ]
                ]

        Session.GoogleError _ ->
            div [] [ text "Google failed to sign in" ]

        Session.NetworkError error ->
            div [] [ text "Network error validating" ]

        Session.AccessDenied ->
            div [] [ text "Access denied!" ]


viewValidated : User -> Session.GoogleUser -> Html msg
viewValidated user google_user =
    span [ class "level" ]
        ([ div [ class "level-left" ]
            [ p [ class "has-text-left", class "level-item" ]
                [ text (user.first_name ++ " " ++ user.last_name) ]
            ]
         ]
            |> (\l ->
                    case google_user.image_url of
                        Just image_url ->
                            List.append l
                                [ div [ class "level-right" ]
                                    [ div
                                        [ class "image is-32x32"
                                        , class "level-item"
                                        ]
                                        [ img [ src image_url ] [] ]
                                    ]
                                ]

                        Nothing ->
                            l
               )
        )


view : Model -> Browser.Document Msg
view model =
    { title = "A-Team!"
    , body =
        [ div []
            [ nav [ class "navbar", class "is-primary" ]
                [ div [ class "navbar-brand" ]
                    [ a [ class "navbar-item", href "/" ]
                        [ img
                            [ src
                                (B.relative [ staticUrl, "logo.svg" ] [])
                            ]
                            []
                        ]
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
                        [ a [ class "navbar-item", href "/" ]
                            [ text "Home" ]
                        , a [ class "navbar-item", href "/users" ]
                            [ text "Users" ]
                        ]
                    , div [ class "navbar-end" ]
                        [ div [ class "navbar-item" ]
                            [ viewSession model.session model.users ]
                        ]
                    ]
                ]
            , div [ class "columns" ]
                [ div [ class "column is-one-fifth" ]
                    (Set.toList model.requests
                        |> List.map (\t -> div [ class "box" ] [ text t ])
                    )
                , div [ class "column" ] [ viewPage model ]
                , div [ class "column is-one-fifth" ]
                    (List.map viewNotification model.notifications)
                ]
            ]
        ]
    }


viewNotification : Notification -> Html msg
viewNotification notification =
    case notification of
        NError t ->
            div [ class "notification is-danger" ] [ text t ]

        NWarning t ->
            div [ class "notification is-warning" ] [ text t ]

        NInfo t ->
            div [ class "notification is-info" ] [ text t ]

        NDebug t ->
            div [ class "notification" ] [ text t ]
