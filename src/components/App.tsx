import React from 'react';
import SafetyTest, {SafteyTestProps} from './SafetyTest'
import Question, {QuestionProps}  from './Question'
import Container from 'react-bootstrap/Container'
import Row from 'react-bootstrap/Row'
import Col from 'react-bootstrap/Col'

export default class App extends React.Component {
    render() {
        return (
            <Container className="App header justify-content-center">
                <Row className="justify-content-center">
                    <h1>Safety Test</h1>
                </Row>
                <SafetyTest />
            </Container>
        )
    }
}
