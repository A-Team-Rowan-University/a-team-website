port module Main exposing
    ( Model
    , Msg(..)
    , init
    , main
    , subscriptions
    , update
    , view
    )

import Browser
import Browser.Navigation as Nav
import Config exposing (..)
import Dict exposing (Dict)
import Errors
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http exposing (Progress, emptyBody, header, jsonBody)
import Json.Decode as D
import Json.Encode as E
import Network exposing (..)
import Platform.Cmd
import Platform.Sub
import Response exposing (Response)
import Session exposing (Session, googleUserDecoder, idToken, isValidated)
import Set exposing (Set)
import Task
import TestSessions.List
import TestSessions.TakeTest
import TestSessions.TestSession
import Tests.List
    exposing
        ( QuestionCategory
        , QuestionCategoryId
        , questionCategoriesUrl
        , questionCategoryListDecoder
        )
import Tests.New
import Time
import Url
import Url.Builder as B
import Url.Parser as P exposing ((</>))
import Users.Detail
import Users.New
import Users.Users as User


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


port signOut : () -> Cmd msg



-- MODEL


type Route
    = Home
    | Users
    | UserDetail User.Id
    | UserNew
    | Tests
    | TestNew
    | TestSessions (Maybe Tests.List.Id)
    | TestSession TestSessions.TestSession.Id
    | TestTake TestSessions.TestSession.Id
    | NotFound


routeParser : P.Parser (Route -> a) a
routeParser =
    P.oneOf
        [ P.map Home P.top
        , P.map Users (P.s "users")
        , P.map UserDetail (P.s "users" </> P.int)
        , P.map UserNew (P.s "users" </> P.s "new")
        , P.map Tests (P.s "tests")
        , P.map TestNew (P.s "tests" </> P.s "new")
        , P.map (TestSessions Nothing) (P.s "tests" </> P.s "sessions")
        , P.map (\id -> TestSessions (Just id)) (P.s "tests" </> P.int)
        , P.map TestSession (P.s "tests" </> P.s "sessions" </> P.int)
        , P.map TestTake (P.s "tests" </> P.s "sessions" </> P.int </> P.s "take")
        ]


type alias Model =
    { navkey : Nav.Key
    , route : Route
    , session : Session User.Id
    , timezone : Maybe Time.Zone
    , users : Dict User.Id User.User
    , user_detail : Users.Detail.State
    , user_new : Users.New.State
    , question_categories : Dict QuestionCategoryId QuestionCategory
    , tests : Dict Tests.List.Id Tests.List.Test
    , test_new : Tests.New.State
    , registrations : Dict TestSessions.TestSession.RegistrationId TestSessions.TestSession.Registration
    , test_sessions : Dict TestSessions.TestSession.Id TestSessions.TestSession.Session
    , test_sessions_state : TestSessions.List.State
    , test_questions : Dict TestSessions.TakeTest.QuestionId TestSessions.TakeTest.AnonymousQuestion
    , test_take : Maybe TestSessions.TakeTest.State
    , requests : Set String
    , notifications : List Errors.Display
    , burger_open : Bool
    }


handleRequestChanges : List RequestChange -> Set String -> Set String
handleRequestChanges request_changes original_requests =
    List.foldr
        (\request_change requests ->
            case request_change of
                AddRequest r ->
                    Set.insert r requests

                RemoveRequest r ->
                    Set.remove r requests
        )
        original_requests
        request_changes


handleResponse :
    Model
    -> (Model -> s -> Model)
    -> (msg -> Msg)
    -> Response s msg
    -> ( Model, Cmd Msg )
handleResponse model local_state msg response =
    let
        ( cmd, requests, errors ) =
            if response.reload then
                let
                    ( load_cmd, load_request, load_errors ) =
                        loadData model.session model.route
                in
                ( Cmd.batch [ Cmd.map msg response.cmd, load_cmd ]
                , response.requests ++ load_request
                , response.errors ++ load_errors
                )

            else
                ( Cmd.map msg response.cmd
                , response.requests
                , response.errors
                )

        updated_model =
            local_state model response.state
    in
    ( { updated_model
        | requests = handleRequestChanges requests model.requests
        , notifications = model.notifications ++ List.map Errors.display errors
      }
    , cmd
    )


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { navkey = key
      , route = Maybe.withDefault NotFound (P.parse routeParser url)
      , session = Session.NotSignedIn
      , timezone = Nothing
      , users = Dict.empty
      , user_detail = Users.Detail.init
      , user_new = Users.New.init
      , test_new = Tests.New.init
      , question_categories = Dict.empty
      , tests = Dict.empty
      , registrations = Dict.empty
      , test_sessions = Dict.empty
      , test_sessions_state = TestSessions.List.init
      , test_questions = Dict.empty
      , test_take = Nothing
      , requests = Set.empty
      , notifications = []
      , burger_open = False
      }
    , Task.perform GotTimezone Time.here
    )



-- UPDATE


type Msg
    = SignedIn E.Value
    | Validated (Result Errors.Error User.User)
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotTimezone Time.Zone
    | GotUsers (Result Errors.Error (List User.User))
    | GotUser User.Id (Result Errors.Error User.User)
    | GotTests (Result Errors.Error (List Tests.List.Test))
    | GotQuestionCategories (Result Errors.Error (List QuestionCategory))
    | GotTestSession TestSessions.TestSession.Id (Result Errors.Error TestSessions.TestSession.Session)
    | GotTestSessions (Result Errors.Error (List TestSessions.TestSession.Session))
    | UserDetailMsg Users.Detail.Msg
    | UserNewMsg Users.New.Msg
    | TestNewMsg Tests.New.Msg
    | TestSessionMsg TestSessions.TestSession.Msg
    | TestSessionsMsg TestSessions.List.Msg
    | TestTakeMsg TestSessions.TakeTest.Msg
    | Updated (Result Errors.Error ())
    | CloseNotification Int
    | BurgerToggle
    | SignOut


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SignedIn user_json ->
            case D.decodeValue googleUserDecoder user_json of
                Ok google_user ->
                    ( { model
                        | session = Session.SignedIn google_user
                      }
                    , Http.request
                        { method = "GET"
                        , headers =
                            [ header
                                "id_token"
                                google_user.id_token
                            ]
                        , url =
                            B.relative [ apiUrl, "users", "current" ]
                                []
                        , body = emptyBody
                        , expect = Errors.expectJsonWithError Validated User.decoder
                        , timeout = Nothing
                        , tracker = Nothing
                        }
                    )

                Err e ->
                    ( { model | session = Session.GoogleError e }
                    , Cmd.none
                    )

        Validated user_result ->
            case model.session of
                Session.SignedIn google_user ->
                    case user_result of
                        Ok user ->
                            let
                                session =
                                    Session.Validated user.id google_user

                                ( cmd, request, errors ) =
                                    loadData session model.route
                            in
                            ( { model
                                | session = session
                                , users =
                                    Dict.insert
                                        user.id
                                        user
                                        model.users
                                , requests =
                                    handleRequestChanges
                                        request
                                        model.requests
                                , notifications =
                                    model.notifications ++ List.map Errors.display errors
                              }
                            , cmd
                            )

                        Err e ->
                            ( { model
                                | session = Session.NotSignedIn
                                , notifications =
                                    model.notifications ++ [ Errors.display e ]
                              }
                            , signOut ()
                            )

                _ ->
                    ( model, Cmd.none )

        GotTimezone zone ->
            ( { model | timezone = Just zone }, Cmd.none )

        GotUsers users_result ->
            ( case users_result of
                Ok users ->
                    { model
                        | users =
                            Dict.fromList
                                (List.map (\u -> ( u.id, u )) users)
                        , requests =
                            handleRequestChanges
                                [ User.manyUrl |> RemoveRequest ]
                                model.requests
                    }

                Err e ->
                    { model
                        | requests =
                            handleRequestChanges
                                [ User.manyUrl |> RemoveRequest ]
                                model.requests
                    }
            , Cmd.none
            )

        GotUser id user_result ->
            ( case user_result of
                Ok user ->
                    { model
                        | users = Dict.insert user.id user model.users
                        , requests =
                            handleRequestChanges
                                [ User.singleUrl id |> RemoveRequest ]
                                model.requests
                    }

                Err e ->
                    { model
                        | requests =
                            handleRequestChanges
                                [ User.singleUrl id |> RemoveRequest ]
                                model.requests
                    }
            , Cmd.none
            )

        GotTests tests_result ->
            ( case tests_result of
                Ok tests ->
                    { model
                        | tests =
                            Dict.fromList
                                (List.map (\u -> ( u.id, u )) tests)
                        , requests =
                            handleRequestChanges
                                [ Tests.List.manyUrl |> RemoveRequest ]
                                model.requests
                    }

                Err e ->
                    { model
                        | requests =
                            handleRequestChanges
                                [ Tests.List.manyUrl |> RemoveRequest ]
                                model.requests
                        , notifications = model.notifications ++ [ Errors.display e ]
                    }
            , Cmd.none
            )

        GotQuestionCategories question_categories_result ->
            ( case question_categories_result of
                Ok question_categories ->
                    { model
                        | question_categories =
                            Dict.fromList
                                (List.map (\u -> ( u.id, u )) question_categories)
                        , requests =
                            handleRequestChanges
                                [ questionCategoriesUrl |> RemoveRequest ]
                                model.requests
                    }

                Err e ->
                    let
                        notifications =
                            model.notifications
                    in
                    { model
                        | requests =
                            handleRequestChanges
                                [ questionCategoriesUrl |> RemoveRequest ]
                                model.requests
                        , notifications = model.notifications ++ [ Errors.display e ]
                    }
            , Cmd.none
            )

        GotTestSessions test_sessions_result ->
            ( case test_sessions_result of
                Ok test_sessions ->
                    { model
                        | test_sessions =
                            Dict.fromList
                                (List.map (\u -> ( u.id, u )) test_sessions)
                        , requests =
                            handleRequestChanges
                                [ RemoveRequest TestSessions.List.url ]
                                model.requests
                    }

                Err e ->
                    let
                        notifications =
                            model.notifications
                    in
                    { model
                        | requests =
                            handleRequestChanges
                                [ RemoveRequest TestSessions.List.url ]
                                model.requests
                        , notifications = model.notifications ++ [ Errors.display e ]
                    }
            , Cmd.none
            )

        GotTestSession id session_result ->
            ( case session_result of
                Ok session ->
                    { model
                        | test_sessions = Dict.insert session.id session model.test_sessions
                        , requests =
                            handleRequestChanges
                                [ RemoveRequest (TestSessions.TestSession.url id) ]
                                model.requests
                    }

                Err e ->
                    { model
                        | requests =
                            handleRequestChanges
                                [ RemoveRequest (TestSessions.TestSession.url id) ]
                                model.requests
                    }
            , Cmd.none
            )

        UserDetailMsg detail_msg ->
            case ( model.route, idToken model.session ) of
                ( UserDetail id, Just id_token ) ->
                    Users.Detail.update id_token model.user_detail detail_msg id
                        |> handleResponse
                            model
                            (\m s -> { m | user_detail = s })
                            UserDetailMsg

                _ ->
                    ( model, Cmd.none )

        UserNewMsg new_msg ->
            case idToken model.session of
                Just id_token ->
                    Users.New.update id_token model.user_new new_msg
                        |> handleResponse
                            model
                            (\m s -> { m | user_new = s })
                            UserNewMsg

                Nothing ->
                    ( model, Cmd.none )

        TestNewMsg new_msg ->
            case idToken model.session of
                Just id_token ->
                    Tests.New.update id_token model.test_new new_msg
                        |> handleResponse
                            model
                            (\m s -> { m | test_new = s })
                            TestNewMsg

                Nothing ->
                    ( model, Cmd.none )

        TestSessionMsg session_msg ->
            case ( model.route, idToken model.session ) of
                ( TestSession id, Just id_token ) ->
                    TestSessions.TestSession.update id_token session_msg id
                        |> handleResponse
                            model
                            (\m s -> m)
                            TestSessionMsg

                _ ->
                    ( model, Cmd.none )

        TestSessionsMsg session_msg ->
            case ( model.route, idToken model.session ) of
                ( TestSessions id, Just id_token ) ->
                    TestSessions.List.update id_token model.test_sessions_state session_msg
                        |> handleResponse
                            model
                            (\m s -> { m | test_sessions_state = s })
                            TestSessionsMsg

                _ ->
                    ( model, Cmd.none )

        TestTakeMsg new_msg ->
            case ( model.route, idToken model.session ) of
                ( TestTake test_session_id, Just id_token ) ->
                    TestSessions.TakeTest.update id_token test_session_id model.test_take new_msg
                        |> handleResponse
                            model
                            (\m s -> { m | test_take = s })
                            TestTakeMsg

                _ ->
                    ( model, Cmd.none )

        Updated _ ->
            let
                ( cmd, request, errors ) =
                    loadData model.session model.route
            in
            ( { model
                | requests =
                    handleRequestChanges
                        request
                        model.requests
                , notifications = model.notifications ++ List.map Errors.display errors
              }
            , cmd
            )

        CloseNotification index ->
            ( { model
                | notifications =
                    List.take index model.notifications
                        ++ List.drop (index + 1) model.notifications
              }
            , Cmd.none
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
                        ( cmd, request, errors ) =
                            loadData model.session route
                    in
                    ( { model
                        | route = route
                        , requests =
                            handleRequestChanges
                                request
                                model.requests
                        , notifications = model.notifications ++ List.map Errors.display errors
                      }
                    , cmd
                    )

        BurgerToggle ->
            ( { model | burger_open = not model.burger_open }, Cmd.none )

        SignOut ->
            ( model, Cmd.batch [ signOut (), Nav.load "/" ] )


loadData :
    Session User.Id
    -> Route
    -> ( Cmd Msg, List RequestChange, List Errors.Error )
loadData session route =
    case route of
        Home ->
            ( Cmd.none, [], [] )

        Users ->
            case idToken session of
                Just id_token ->
                    ( Http.request
                        { method = "GET"
                        , headers = [ header "id_token" id_token ]
                        , url = User.manyUrl
                        , body = emptyBody
                        , expect = Errors.expectJsonWithError GotUsers User.listDecoder
                        , timeout = Nothing
                        , tracker = User.manyUrl |> Just
                        }
                    , [ User.manyUrl |> AddRequest ]
                    , []
                    )

                Nothing ->
                    ( Cmd.none
                    , []
                    , [ Errors.NotLoggedIn ]
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
                        , url = User.singleUrl user_id
                        , body = emptyBody
                        , expect =
                            Errors.expectJsonWithError
                                (GotUser user_id)
                                User.decoder
                        , timeout = Nothing
                        , tracker = User.singleUrl user_id |> Just
                        }
                    , [ User.singleUrl user_id |> AddRequest ]
                    , []
                    )

                Nothing ->
                    ( Cmd.none
                    , []
                    , [ Errors.NotLoggedIn ]
                    )

        UserNew ->
            ( Cmd.none, [], [] )

        Tests ->
            case idToken session of
                Just id_token ->
                    ( Http.request
                        { method = "GET"
                        , headers = [ header "id_token" id_token ]
                        , url = Tests.List.manyUrl
                        , body = emptyBody
                        , expect = Errors.expectJsonWithError GotTests Tests.List.listDecoder
                        , timeout = Nothing
                        , tracker = Tests.List.manyUrl |> Just
                        }
                    , [ Tests.List.manyUrl |> AddRequest ]
                    , []
                    )

                Nothing ->
                    ( Cmd.none
                    , []
                    , [ Errors.NotLoggedIn ]
                    )

        TestNew ->
            case idToken session of
                Just id_token ->
                    ( Http.request
                        { method = "GET"
                        , headers = [ header "id_token" id_token ]
                        , url = questionCategoriesUrl
                        , body = emptyBody
                        , expect =
                            Errors.expectJsonWithError GotQuestionCategories
                                questionCategoryListDecoder
                        , timeout = Nothing
                        , tracker = Just questionCategoriesUrl
                        }
                    , [ AddRequest questionCategoriesUrl ]
                    , []
                    )

                Nothing ->
                    ( Cmd.none
                    , []
                    , [ Errors.NotLoggedIn ]
                    )

        TestSessions _ ->
            case idToken session of
                Just id_token ->
                    ( Http.request
                        { method = "GET"
                        , headers = [ header "id_token" id_token ]
                        , url = TestSessions.List.url
                        , body = emptyBody
                        , expect = Errors.expectJsonWithError GotTestSessions TestSessions.List.decoder
                        , timeout = Nothing
                        , tracker = Just TestSessions.List.url
                        }
                    , [ AddRequest TestSessions.List.url ]
                    , []
                    )

                Nothing ->
                    ( Cmd.none
                    , []
                    , [ Errors.NotLoggedIn ]
                    )

        TestSession session_id ->
            case idToken session of
                Just id_token ->
                    ( Http.request
                        { method = "GET"
                        , headers = [ header "id_token" id_token ]
                        , url = TestSessions.TestSession.url session_id
                        , body = emptyBody
                        , expect = Errors.expectJsonWithError (GotTestSession session_id) TestSessions.TestSession.decoder
                        , timeout = Nothing
                        , tracker = Just (TestSessions.TestSession.url session_id)
                        }
                    , [ AddRequest (TestSessions.TestSession.url session_id) ]
                    , []
                    )

                Nothing ->
                    ( Cmd.none
                    , []
                    , [ Errors.NotLoggedIn ]
                    )

        TestTake test_session_id ->
            case idToken session of
                Just id_token ->
                    let
                        ( cmd, requests, errors ) =
                            TestSessions.TakeTest.loadData id_token test_session_id
                    in
                    ( Cmd.map TestTakeMsg cmd, requests, errors )

                Nothing ->
                    ( Cmd.none
                    , []
                    , [ Errors.NotLoggedIn ]
                    )

        NotFound ->
            ( Cmd.none, [], [] )


viewPage : Model -> Html Msg
viewPage model =
    case model.route of
        Users ->
            User.viewList model.users

        UserDetail user_id ->
            case Dict.get user_id model.users of
                Just user ->
                    Users.Detail.view user model.user_detail
                        |> Html.map UserDetailMsg

                Nothing ->
                    p [] [ text "User not found" ]

        UserNew ->
            Users.New.view model.user_new |> Html.map UserNewMsg

        Tests ->
            Tests.List.viewList model.users model.tests

        TestNew ->
            Tests.New.view model.question_categories model.test_new
                |> Html.map TestNewMsg

        TestSessions test_filter ->
            case model.session of
                Session.Validated userid googleuser ->
                    TestSessions.List.view userid
                        model.test_sessions
                        (Maybe.andThen
                            (\test -> Dict.get test model.tests)
                            test_filter
                        )
                        model.test_sessions_state
                        |> Html.map TestSessionsMsg

                _ ->
                    p [] [ text "You must be logged in" ]

        TestSession session_id ->
            case Dict.get session_id model.test_sessions of
                Just session ->
                    TestSessions.TestSession.view model.timezone model.users session
                        |> Html.map TestSessionMsg

                Nothing ->
                    p [] [ text "Test session not found" ]

        TestTake session_id ->
            TestSessions.TakeTest.view model.test_take |> Html.map TestTakeMsg

        Home ->
            h1 [] [ text "Welcome to the A-Team!" ]

        NotFound ->
            h1 [] [ text "Page not found!" ]


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
                        , href ""
                        , class "navbar-burger"
                        , class "burger"
                        , attribute "aria-label" "menu"
                        , attribute "aria-expanded" "false"
                        , attribute "data-target" "navbar"
                        , onClick BurgerToggle
                        , classList [ ( "is-active", model.burger_open ) ]
                        ]
                        [ span [ attribute "aria-hidden" "true" ] []
                        , span [ attribute "aria-hidden" "true" ] []
                        , span [ attribute "aria-hidden" "true" ] []
                        ]
                    ]
                , div
                    [ id "navbar"
                    , class "navbar-menu"
                    , classList [ ( "is-active", model.burger_open ) ]
                    ]
                    [ div [ class "navbar-start" ]
                        [ a [ class "navbar-item", href "/" ]
                            [ text "Home" ]
                        , a [ class "navbar-item", href "/users" ]
                            [ text "Users" ]
                        , a [ class "navbar-item", href "/tests" ]
                            [ text "Tests" ]
                        ]
                    , div [ class "navbar-end" ]
                        [ div [ class "navbar-item has-dropdown is-hoverable" ]
                            [ div [ class "navbar-link" ]
                                [ case model.session of
                                    Session.Validated user_id google_user ->
                                        case Dict.get user_id model.users of
                                            Just user ->
                                                case google_user.image_url of
                                                    Just image_url ->
                                                        div
                                                            [ class "image is-32x32"
                                                            , class "level-item"
                                                            ]
                                                            [ img [ src image_url ] [] ]

                                                    Nothing ->
                                                        p [] [ text (user.first_name ++ " " ++ user.last_name) ]

                                            Nothing ->
                                                div [] [ text "User not found!" ]

                                    Session.SignedIn google_iser ->
                                        div [] [ text "Validating..." ]

                                    Session.NotSignedIn ->
                                        div [] [ text "Sign In" ]

                                    Session.GoogleError _ ->
                                        div [] [ text "Google failed to sign in" ]
                                ]
                            , div [ class "navbar-dropdown is-right", classList [ ( "is-hidden", isValidated model.session ) ] ]
                                [ div [ class "navbar-item" ]
                                    [ div
                                        [ class "g-signin2"
                                        , attribute "data-onsuccess" "onSignIn"
                                        ]
                                        []
                                    ]
                                ]
                            , div [ class "navbar-dropdown is-right", classList [ ( "is-hidden", not (isValidated model.session) ) ] ]
                                [ a [ href "/", class "navbar-item", onClick SignOut ] [ text "Sign Out" ] ]
                            ]
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
                    (List.indexedMap (viewNotification CloseNotification) model.notifications)
                ]
            ]
        ]
    }


viewNotification : (Int -> msg) -> Int -> Errors.Display -> Html msg
viewNotification onClose index notification =
    div [ class "notification is-danger" ]
        [ button [ class "delete", onClick (onClose index) ] []
        , p [ class "title is-5" ] [ text notification.title ]
        , p [ class "is-5" ] [ text notification.description ]
        ]


httpErrorToString : Http.Error -> String
httpErrorToString e =
    case e of
        Http.BadUrl s ->
            "Bad url: " ++ s

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network Error"

        Http.BadStatus status ->
            "Bad status: " ++ String.fromInt status

        Http.BadBody s ->
            "Bad body: \n" ++ s
