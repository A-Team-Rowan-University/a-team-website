import React from 'react'
import {Row, Col, ToggleButton, ButtonGroup, Container} from 'react-bootstrap'

export default class Question extends React.Component<QuestionProps, QuestionState> {

    constructor(props: QuestionProps) {
        super(props);
        this.state = {selectedChoice: undefined}
    }

    onChoiceClicked(e: React.MouseEvent<HTMLElement>) {
        e.preventDefault();
        this.updateSelectedChoice(parseInt(e.currentTarget.id))
    }

    updateSelectedChoice(id: number) {
        const prevState = this.state;

        if(prevState.selectedChoice !== id)
            this.setState({selectedChoice: id})
        else
            this.setState({selectedChoice: undefined})
    }

    render() {
        return (
            <Container id={this.props.id.toString()} className="question">
                <Row className="justify-content-center">
                    <h2>{this.props.question}</h2>
                </Row>
                <Row className="justify-content-center">
                    {
                    this.props.choices.map((choice: Choice): any =>
                    <Col xs={12} md={2} id={choice.id.toString()} key={choice.id.toString()} className="choice" onClick={this.onChoiceClicked.bind(this)}>
                        <ButtonGroup toggle>
                            <ToggleButton type="checkbox" value={choice.id} checked={this.state.selectedChoice === choice.id}>{choice.text}</ToggleButton>
                        </ButtonGroup>
                    </Col>)
                    }
                </Row>
            </Container>
        )
}
}

export interface QuestionProps {
    id: number;
    question: string;
    choices: Choice[];
}

interface QuestionState {
    selectedChoice?: number
}

interface Choice {
    id: number;
    text: string;
}

