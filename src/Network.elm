module Network exposing (Network(..), viewNetwork, viewNetwork2)

import Html exposing (Html, div, progress, text)
import Html.Attributes exposing (class)
import Http


type Network a
    = Loading
    | Loaded a
    | NetworkError Http.Error


viewNetwork : (a -> Html msg) -> Network a -> Html msg
viewNetwork viewFunc network =
    case network of
        Loading ->
            progress [ class "progress is-info is-small" ] []

        Loaded a ->
            viewFunc a

        NetworkError e ->
            div [ class "notification is-danger" ]
                [ text "There was a problem with the network. The shown data may not be up to date." ]


viewNetwork2 : (a -> b -> Html msg) -> Network a -> Network b -> Html msg
viewNetwork2 viewFunc network_a network_b =
    case ( network_a, network_b ) of
        ( Loading, Loading ) ->
            div [] [ text "Loading..." ]

        ( Loading, Loaded a ) ->
            div [] [ text "Loading..." ]

        ( Loaded a, Loading ) ->
            div [] [ text "Loading..." ]

        ( Loaded a, Loaded b ) ->
            viewFunc a b

        ( NetworkError e, _ ) ->
            div [] [ text "Network error!" ]

        ( _, NetworkError e ) ->
            div [] [ text "Network error!" ]
