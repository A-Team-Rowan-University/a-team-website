import React from 'react'

export default class SafetyTest extends React.Component<SafetyTestProps> {
    render() {
        return (
            <div className="test">
                <h1>Safety Test</h1>
                {this.props.questions}
            </div>
        )
    }
}

export interface SafetyTestProps {
    questions: any;
}