import React from 'react'

interface SafetyTestProps {
    questions: Array<Question>;
}

type QuestionProps = {
    question: string;
    choices: Readonly<Array<Choice>>;
}

type Choice = {
    text: string;
    selected: boolean;
}

class Question extends React.Component {

    render() {
        return (
            <div className="question">
                <h1>props.question</h1>
                {
                    this.props.choices.map((choice: Choice, i: number): any => {
                        <p key={i} className={"choice" + (choice.selected ? 'selected' : '')}>
                            choice.text
                    </p>
                    })
                }
            </div>
        )
    }
}

export default class SafetyTest extends React.Component<any, SafetyTestProps> {
    constructor(props: SafetyTestProps){
        super(props)
        this.state.questions = props.questions;
    }
    render() {
        return (
            <div className="test">
                <h1>Safety Test</h1>
                {
                    this.qu
                }
            </div>
        )
    }
}