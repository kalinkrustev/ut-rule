import React, { PropTypes } from 'react';
import {SimpleGrid} from 'ut-front-react/components/SimpleGrid';
import ContextMenu from '../ContextMenu';
import style from './style.css';
import classnames from 'classnames';

const nestedTable = function(arr, className) {
    return <table className={classnames(style.nested, className)}>
        <tbody>
            {
                arr.map((tr, i) => {
                    return <tr key={i}>
                        {
                            (Array.isArray(tr) ? tr : [tr]).map((td, j) => {
                                return <td key={j}>{td}</td>;
                            })
                        }
                    </tr>;
                })
            }
        </tbody>
    </table>;
};

const buildCSV = function(arr) {
    if (typeof arr === 'object') {
        return arr.map((record) => {
            return record.value ? ((record.key ? record.key + ': ' : '') + record.value) : '';
        }).filter(val => val).join(' | ');
    }
};

export default React.createClass({
    propTypes: {
        data: PropTypes.object,
        nomenclatures: PropTypes.object,
        selectedConditions: PropTypes.object,
        refresh: PropTypes.func,
        handleCheckboxSelect: PropTypes.func,
        handleHeaderCheckboxSelect: PropTypes.func
    },
    getInitialState() {
        return {
            columns: {
                priority: {
                    visible: true,
                    title: 'Priority'
                },
                channel: {
                    visible: true,
                    title: 'Channel'
                },
                operation: {
                    visible: true,
                    title: 'Operation'
                },
                source: {
                    visible: true,
                    title: 'Source'
                },
                destination: {
                    visible: true,
                    title: 'Destination'
                },
                fee: {
                    visible: true,
                    title: 'Fee'
                },
                commission: {
                    visible: false,
                    title: 'Commission'
                },
                limit: {
                    visible: true,
                    title: 'Limit'
                }
            }
        };
    },
    shouldComponentUpdate(nextProps, nextState) {
        return true;
    },
    buildList(arr) {
        // label, value, nomenclatureKey
        if (typeof arr === 'object') {
            return arr.map((record, i) => {
                let value = record[2] && this.props.nomenclatures[record[2]] ? this.props.nomenclatures[record[2]][record[1]] : record[1];
                return (
                    value
                    ? <div key={i}>
                        <b>{record[0] ? record[0] + ': ' : ''}</b>{value}
                    </div>
                    : null
                );
            });
        }
    },
    updateColumns(columns) {
        this.setState({
            columns: columns
        });
    },
    handleRowClick(record, index) {
        this.props.handleCheckboxSelect(null, record);
    },
    getData() {
        return Object.keys(this.props.data).map((conditionId, i) => {
            let record = this.props.data[conditionId];
            let condition = record.condition[0];
            let columns = this.state.columns;
            return {
                id: conditionId,
                priority: columns.priority.visible && condition.priority,
                channel: columns.channel.visible && [
                    ['Channel', condition.channelId, 'channel'],
                    ['Tag', condition.channelTag],
                    ['Country', condition.channelCountryId, 'country'],
                    ['Region', condition.channelRegionId, 'region'],
                    ['City', condition.channelCityId, 'city'],
                    ['Organization', condition.channelOrganizationId, 'organization'],
                    ['Supervisor', condition.channelSupervisorId, 'supervisor'],
                    ['Role', condition.channelRoleId, 'role']
                ],
                operation: columns.operation.visible && [
                    ['Operation', condition.operationId, 'operation'],
                    ['Tag', condition.operationTag],
                    ['Start Date', condition.operationStartDate],
                    ['End Date', condition.operationEndDate]
                ],
                source: columns.source.visible && [
                    ['Country', condition.sourceCountryId, 'country'],
                    ['Region', condition.sourceRegionId, 'region'],
                    ['City', condition.sourceCityId, 'city'],
                    ['Organization', condition.sourceOrganizationId, 'organization'],
                    ['Supervisor', condition.sourceSupervisorId, 'supervisor'],
                    ['Tag', condition.sourceTag]
                ],
                destination: columns.destination.visible && [
                    ['Country', condition.destinationCountryId, 'country'],
                    ['Region', condition.destinationRegionId, 'region'],
                    ['City', condition.destinationCityId, 'city'],
                    ['Organization', condition.destinationOrganizationId, 'organization'],
                    ['Supervisor', condition.destinationSupervisorId, 'supervisor'],
                    ['Tag', condition.destinationTag]
                ],
                fee: columns.fee.visible && record.fee,
                commission: columns.commission.visible && record.commission,
                limit: columns.limit.visible && record.limit,
                refresh: ''
            };
        });
    },
    transformCellValue(value, header, row) {
        if (!value) {
            return;
        }
        switch (header.name) {
            case 'channel':
            case 'operation':
            case 'source':
            case 'destination':
                return this.buildList(value);
            case 'fee':
                if (typeof value === 'object') {
                    return nestedTable(value.reduce((all, record) => {
                        all.push([
                            '>= ' + record.startAmount + ' ' + this.props.nomenclatures.currency[record.startAmountCurrency],
                            buildCSV([
                                {
                                    key: '',
                                    value: record.percent ? record.percent + '%' : ''
                                },
                                {
                                    key: 'base',
                                    value: record.percentBase
                                },
                                {
                                    key: 'min',
                                    value: record.minValue
                                },
                                {
                                    key: 'max',
                                    value: record.maxValue
                                }
                            ])
                        ]);
                        return all;
                    }, []), style.fee);
                }
                break;
            case 'commission':
                if (typeof value === 'object') {
                    return nestedTable(value.reduce((all, record) => {
                        all.push([
                            '>= ' + record.startAmount + ' ' + this.props.nomenclatures.currency[record.startAmountCurrency],
                            buildCSV([
                                {
                                    key: '',
                                    value: record.percent ? record.percent + '%' : ''
                                },
                                {
                                    key: 'base',
                                    value: record.percentBase
                                },
                                {
                                    key: 'min',
                                    value: record.minValue
                                },
                                {
                                    key: 'max',
                                    value: record.maxValue
                                }
                            ])
                        ]);
                        return all;
                    }, []), style.commission);
                }
                break;
            case 'limit':
                if (typeof value === 'object') {
                    return value.map((limit, i) => {
                        return this.buildList([
                            [
                                '',
                                i === 0 ? '' : <hr />
                            ],
                            [
                                'Currency',
                                limit.currency || ''
                            ],
                            [
                                'Transaction',
                                '' + (limit.maxAmount ? 'max ' + limit.maxAmount + ' ' : '') + (limit.minAmount ? 'min ' + limit.minAmount + ' ' : '')
                            ],
                            [
                                'Daily',
                                '' + (limit.maxAmountDaily ? 'max ' + limit.maxAmountDaily + ' ' : '') + (limit.maxCountDaily ? 'count ' + limit.maxCountDaily + ' ' : '')
                            ],
                            [
                                'Weekly',
                                '' + (limit.maxAmountWeekly ? 'max ' + limit.maxAmountWeekly + ' ' : '') + (limit.maxCountWeekly ? 'count ' + limit.maxCountWeekly + ' ' : '')
                            ],
                            [
                                'Monthly',
                                '' + (limit.maxAmountMonthly ? 'max ' + limit.maxAmountMonthly + ' ' : '') + (limit.maxCountMonthly ? 'count ' + limit.maxCountMonthly + ' ' : '')
                            ]
                        ]);
                    });
                }
                break;
            default:
                return value;
        }
    },
    render() {
        let data = this.getData();
        return <SimpleGrid
          ref='grid'
          multiSelect
          fields={[
              {title: 'Priority', name: 'priority'},
              {title: 'Channel', name: 'channel'},
              {title: 'Operation', name: 'operation'},
              {title: 'Source', name: 'source'},
              {title: 'Destination', name: 'destination'},
              {title: 'Fee', name: 'fee', style: {padding: '0', position: 'relative', width: '360px', minWidth: '220px'}},
              {title: 'Commission', name: 'commission', style: {padding: '0', position: 'relative', width: '360px', minWidth: '220px'}},
              {title: 'Limit', name: 'limit'},
              {
                  title: <div style={{float: 'right'}}>
                    <ContextMenu
                      refresh={this.props.refresh}
                      onClose={this.updateColumns}
                      data={this.state.columns}
                    />
                  </div>,
                  name: 'refresh'
              }
          ].filter((column) => (!this.state.columns[column.name] || this.state.columns[column.name].visible))}
          handleCheckboxSelect={this.props.handleCheckboxSelect}
          handleHeaderCheckboxSelect={this.props.handleHeaderCheckboxSelect}
          handleRowClick={this.handleRowClick}
          externalStyle={style}
          mainClassName='dataGridTable'
          rowsChecked={data.filter(x => this.props.selectedConditions[x.id])}
          data={data}
          transformCellValue={this.transformCellValue}
        />;
    }
});
