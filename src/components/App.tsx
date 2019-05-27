import React from 'react';
import SafetyTest, {SafetyTestProps}  from './SafetyTest'
import Question, {QuestionProps}  from './Question'
import Container from 'react-bootstrap/Container'
import Row from 'react-bootstrap/Row'
import Col from 'react-bootstrap/Col'

const q1Props: QuestionProps = {
    id: 1,
    question: 'What is 2+2?',
    choices: [
        {id:1 , text:'1'},
        {id:2 , text:'banana'},
        {id:3 , text:'chimpanzee'},
        {id:4 , text:'4'},
    ]
}

const q2Props: QuestionProps = {
    id: 2,
    question: 'What color is the sky?',
    choices: [
        {id:1 , text:'green'},
        {id:2 , text:'true'},
        {id:3 , text:'a ring-toed lemur'},
        {id:4 , text:'blue'},
    ]
}

export default class App extends React.Component {
    render() {
        return (
            <Container className="App header justify-content-center">
                <Row className="justify-content-center">
                    <h1>Safety Test</h1>
                </Row>
                <Row>
                    <Question {...q1Props}/>
                    <Question {...q2Props}/>
                </Row>
            </Container>
        )
    }
}
