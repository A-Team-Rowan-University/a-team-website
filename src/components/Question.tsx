import React from 'react'

export default class Question extends React.Component<QuestionProps, QuestionState> {

    constructor(props: QuestionProps) {
        super(props);
        this.state = {selectedChoice: undefined}
    }

    onChoiceClicked(e: React.MouseEvent<HTMLElement>) {
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
            <div id={this.props.id.toString()} className="question">
                <h1>{this.props.question}</h1>
                {
                this.props.choices.map((choice: Choice): any =>
                <div id={choice.id.toString()} key={choice.id.toString()} className="choice" onClick={this.onChoiceClicked.bind(this)}>{choice.text}</div>)
                }
            </div>
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

