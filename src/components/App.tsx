import React from 'react';
import SafetyTest, {SafetyTestProps}  from './SafetyTest'
import Question, {QuestionProps}  from './Question'

const q1Props: QuestionProps = {
    id: 1,
    question: 'What is 2+2?',
    choices: [
        {id:1 , text:'1'},
        {id:2 , text:'2'},
        {id:3 , text:'3'},
        {id:4 , text:'4'},
    ]
}

const question1 = React.createElement(Question, q1Props)
const questions = [new Question(q1Props)]

export default class App extends React.Component {
    render() {
        return (
            <div className="App header">
                <h1>Safety Test</h1>
                <Question {...q1Props}/>
            </div>
        )
    }
}
