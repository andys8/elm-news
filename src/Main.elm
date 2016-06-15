port module Main exposing (..)

import Html exposing (Html, a, text, div, h1, span)
import Html.Attributes exposing (href, class)
import Html.App
import Date exposing (Date)
import Task exposing (Task)
import Basics.Extra exposing (never)
import Header
import Footer
import Tag
import Message exposing (..)
import Reddit
import HackerNews
import DateFormatter
import Http


-- TODO rename messages model
-- TODO update times without page reload
-- TODO consider no cards like hacker news or reddit
-- TODO ensure calls are returning the same amount of message or are over a certain time span
-- TODO handle errors
-- TODO spinner for loading
-- TODO mobile and header like http://square.github.io/okhttp/
-- TODO filtering (on header or by clicking tags)
-- TODO google analytics
-- TODO better font and color scheme
-- TODO web checklist
-- TODO purchase domain and setup with gh pages
-- TODO share with others
-- TODO paging to go back further? not sure how this will work
-- TODO create xml parser in elm using json decoders


type alias Model =
    { messages : List Message
    , errors : List ( String, String )
    , now : Maybe Date
    , showHeader : Bool
    }


init : ( Model, Cmd Msg )
init =
    let
        model =
            { messages = []
            , errors = []
            , now = Nothing
            , showHeader = True
            }

        fx =
            Cmd.batch
                [ fetchGoogleGroupMsgs "elm-dev"
                , fetchGoogleGroupMsgs "elm-discuss"
                , fetch Reddit.tag Reddit.fetch
                , fetch HackerNews.tag HackerNews.fetch
                , Task.perform never CurrentDate Date.now
                ]
    in
        ( model
        , fx
        )


type Msg
    = FetchMessageSuccess MessageResp
    | FetchMessageError MessageError
    | CurrentDate Date
    | ScrollUp
    | ScrollDown


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchMessageSuccess resp ->
            let
                updatedModel =
                    { model | messages = model.messages ++ resp.messages }
            in
                ( updatedModel
                , Cmd.none
                )

        FetchMessageError error ->
            let
                updatedModel =
                    { model | errors = ( error.tag, Debug.log "" error.error ) :: model.errors }
            in
                ( updatedModel
                , Cmd.none
                )

        CurrentDate date ->
            ( { model | now = Just date }
            , Cmd.none
            )

        ScrollUp ->
            ( { model | showHeader = True }
            , Cmd.none
            )

        ScrollDown ->
            ( { model | showHeader = False }
            , Cmd.none
            )


view : Model -> Html Msg
view model =
    div [ class "main" ]
        [ Header.view model.showHeader
        , body model
        , Footer.view <| Maybe.map Date.year model.now
        ]


body : Model -> Html Msg
body model =
    div [ class "body" ]
        [ div []
            <| List.map (cardView model.now)
            <| List.reverse
            <| List.sortBy .date model.messages
        ]


cardView : Maybe Date -> Message -> Html Msg
cardView now msg =
    div [ class "card" ]
        [ Tag.view msg.tag
        , div [ class "card__description" ]
            [ div [ class "card__description__header" ]
                [ a
                    [ href msg.link
                    , class "card__description__title black_text"
                    ]
                    [ text msg.title ]
                , span [ class "card__description__domain" ]
                    [ text <| "(" ++ msg.domain ++ ")" ]
                ]
            , div []
                [ text <| "By " ++ msg.author ]
            ]
        , div [ class "card__date" ]
            [ text <| DateFormatter.format now <| Date.fromTime msg.date ]
        ]


fetch : String -> Task Http.Error (List Message) -> Cmd Msg
fetch tag task =
    Task.perform (\error -> FetchMessageError <| MessageError tag <| toString error)
        (\msgs -> FetchMessageSuccess <| MessageResp tag msgs)
        task


port fetchGoogleGroupMsgs : String -> Cmd msg


port fetchedGoogleGroupMsgs : (MessageResp -> msg) -> Sub msg


port errorGoogleGroupMsgs : (MessageError -> msg) -> Sub msg


port scrollUp : (Float -> msg) -> Sub msg


port scrollDown : (Float -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ fetchedGoogleGroupMsgs FetchMessageSuccess
        , errorGoogleGroupMsgs FetchMessageError
        , scrollUp (\_ -> ScrollUp)
        , scrollDown (\_ -> ScrollDown)
        ]


main : Program Never
main =
    Html.App.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
