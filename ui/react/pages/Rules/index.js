import React, { PropTypes } from 'react';
import { connect } from 'react-redux';
import { fromJS } from 'immutable';
import { bindActionCreators } from 'redux';
import Grid from '../../components/Grid';
import ResizibleContainer from 'ut-front-react/components/ResiziblePageLayout/Container';
import resizibleTypes from 'ut-front-react/components/ResiziblePageLayout/resizibleTypes';
import ConfirmDialog from 'ut-front-react/components/ConfirmDialog';
import { getLink } from 'ut-front-react/routerHelper';
import { AddTab } from 'ut-front-react/containers/TabMenu';
import Header from 'ut-front-react/components/PageLayout/Header';
import GridToolBox from 'ut-front-react/components/SimpleGridToolbox';
import AdvancedPagination from 'ut-front-react/components/AdvancedPagination';
import Button from 'ut-front-react/components/StandardButton';
import style from './style.css';
import * as actionCreators from './actionCreators';

const Main = React.createClass({
    propTypes: {
        rules: PropTypes.object,
        nomenclatures: PropTypes.object,
        formatedGridData: PropTypes.object,
        ready: PropTypes.bool,
        actions: PropTypes.object,
        uiConfig: PropTypes.object,
        pagination: PropTypes.object,
        showDeleted: PropTypes.bool
    },
    getInitialState() {
        return {
            selectedConditions: {},
            canEdit: false,
            canDelete: false,
            uiConfig: this.props.uiConfig.toJS()
        };
    },
    fetchData(props) {
        let {pageSize, pageNumber} = props.pagination;
        let showDeleted = props.showDeleted;

        this.props.actions.fetchRules({pageSize, pageNumber}, showDeleted);
        this.props.actions.fetchNomenclatures(this.state.uiConfig.nomenclatures);
    },
    componentWillMount() {
        this.fetchData(this.props);
    },
    componentWillReceiveProps(nextProps) {
        if (this.props.pagination.changeId !== nextProps.pagination.changeId || this.props.showDeleted !== nextProps.showDeleted) {
            this.fetchData(nextProps);
        }
    },
    shouldComponentUpdate(nextProps, nextState) {
        return nextProps.ready;
    },
    handleCheckboxSelect(isSelected, data) {
        let selectedConditions = this.state.selectedConditions;
        if (isSelected === null) {
            isSelected = selectedConditions[data.id];
        }
        if (isSelected) {
            delete selectedConditions[data.id];
        } else {
            selectedConditions[data.id] = true;
        }
        let count = Object.keys(selectedConditions).length;
        this.setState({
            selectedConditions: selectedConditions,
            canEdit: count === 1,
            canDelete: count > 0
        });
        return !isSelected;
    },
    handleHeaderCheckboxSelect(isSelected) {
        this.setState({
            selectedConditions: isSelected ? {} : Object.keys(this.props.rules).reduce((all, key) => { all[key] = true; return all; }, {}),
            canEdit: false,
            canDelete: !isSelected
        });
    },
    removeRules() {
        let conditionsArray = Object.keys(this.state.selectedConditions).map((key) => (parseInt(key, 10)));
        this.setState(this.getInitialState(), () => this.props.actions.removeRules({
            conditionId: conditionsArray
        }));
    },
    refresh() {
        this.setState(this.getInitialState(), () => this.props.actions.reset());
    },
    showConfirm() {
        this.refs['showRuleConfirmDialog'] && this.refs['showRuleConfirmDialog'].open();
    },
    getHeaderButtons() {
        let buttons = [];
        this.context.checkPermission('rule.rule.add') &&
            buttons.push({text: 'Create Rule', href: getLink('ut-rule:create'), styleType: 'primaryLight'});
        return buttons;
    },
    render() {
        if (!this.props.ready) {
            return null;
        }

        let uiConfig = this.state.uiConfig;
        let columns = uiConfig.main.grid.columns;
        let id = Object.keys(this.state.selectedConditions)[0];
        let showDeleted = this.props.showDeleted;
        let content = [
            <GridToolBox contentWrapClassName={style.actionWrap} cssStandard opened title='' >
                { this.context.checkPermission('rule.rule.edit') && !showDeleted &&
                (<Button label='Edit' href={getLink('ut-rule:edit', { id })} disabled={!this.state.canEdit} className='defaultBtn' />)}
                { this.context.checkPermission('rule.rule.remove') && !showDeleted &&
                (<Button label='Delete' disabled={!this.state.canDelete} className='defaultBtn' onClick={this.showConfirm} />)}
                { this.context.checkPermission('rule.rule.fetchDeleted') &&
                (<Button className={showDeleted ? [style.buttonToggle, style.buttonLarge] : style.buttonLarge}
                    onClick={() => { this.props.actions.toggleRuleOption('showDeleted', !showDeleted); }} styleType={showDeleted ? 'primaryLight' : 'secondaryLight'} label={'Show Deleted'} />)}
            </GridToolBox>,
            <Grid
                ref='grid'
                refresh={this.refresh}
                data={this.props.rules}
                selectedConditions={this.state.selectedConditions}
                nomenclatures={this.props.nomenclatures}
                formatedGridData={this.props.formatedGridData}
                handleCheckboxSelect={this.handleCheckboxSelect}
                handleHeaderCheckboxSelect={this.handleHeaderCheckboxSelect}
                columns={columns}
                showDeleted={this.props.showDeleted} />,
            <AdvancedPagination
                cssStandard
                onUpdate={this.props.actions.updatePagination}
                pagination={fromJS(this.props.pagination)} />
        ];
        let resizibleContainerCols = [
            {type: resizibleTypes.CONTENT, id: 'cardReasonContent', minWidth: 1200, child: content}
        ];
        return (
            <div>
                <AddTab pathname={getLink('ut-rule:rules')} title='Fees, Commissions and Limits (FCL)' />
                <Header text='Fees, Commissions and Limits (FCL)' buttons={this.getHeaderButtons()} />
                <ResizibleContainer cssStandard cols={resizibleContainerCols} />
                <ConfirmDialog
                    ref={'showRuleConfirmDialog'}
                    submitLabel='Yes'
                    title='Warning'
                    message={
                        'You are about to delete ' +
                    (
                        Object.keys(this.state.selectedConditions).length === 1
                            ? '1 rule'
                            : Object.keys(this.state.selectedConditions).length + ' rules'
                    ) +
                    '. Would you like to proceed?'}
                    onSubmit={this.removeRules} />
            </div>
        );
    }
});

Main.contextTypes = {
    checkPermission: PropTypes.func.isRequired
};

export default connect(
    (state, ownProps) => {
        return {
            rules: state.ruleList.fetchRules,
            nomenclatures: state.ruleList.fetchNomenclatures,
            formatedGridData: state.ruleList.formatedGridData,
            ready: !!(state.ruleList.fetchRules && state.ruleList.fetchNomenclatures),
            roles: state.ruleList.fetchRoles,
            organizations: state.ruleList.fetchOrganizations,
            uiConfig: state.uiConfig,
            pagination: state.ruleList.pagination || {
                pageSize: 25,
                pageNumber: 1,
                recordsTotal: 0
            },
            showDeleted: state.ruleList.showDeleted
        };
    },
    (dispatch) => {
        return {
            actions: bindActionCreators(actionCreators, dispatch)
        };
    }
)(Main);
