module Network exposing
    ( Network(..)
    , RequestChange(..)
    , viewNetwork
    )

import Html exposing (Html, div, progress, text)
import Html.Attributes exposing (class)
import Http

type RequestChange
    = AddRequest String
    | RemoveRequest String


type Network a
    = NotLoaded
    | Loading (Maybe a)
    | Loaded a
    | NetworkError Http.Error
    | AccessDenied


viewNetwork : (a -> Html msg) -> Network a -> Html msg
viewNetwork viewFunc network =
    case network of
        NotLoaded ->
            div [] [ text "Not loaded yet" ]

        Loading ma ->
            case ma of
                Just a ->
                    div []
                        [ progress
                            [ class "progress is-info is-small" ]
                            []
                        , viewFunc a
                        ]

                Nothing ->
                    progress [ class "progress is-info is-small" ] []

        Loaded a ->
            viewFunc a

        NetworkError e ->
            div [ class "notification is-danger" ]
                [ text "There was a problem with the network. The shown data may not be up to date." ]

        AccessDenied ->
            div [ class "notification is-warning" ]
                [ text "You do not have permission for this request" ]
