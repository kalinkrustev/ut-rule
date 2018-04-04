const splitTags = [
    {key: 'acquirer', name: 'Acquirer'},
    {key: 'issuer', name: 'Issuer'},
    {key: 'commission', name: 'Commission'},
    {key: 'realtime', name: 'Realtime posting'},
    {key: 'pending', name: 'Authorization required'},
    {key: 'agent', name: 'Agent'},
    {key: 'fee', name: 'Fee'},
    {key: 'atm', name: 'ATM'},
    {key: 'pos', name: 'POS'},
    {key: 'ped', name: 'PED'},
    {key: 'vendor', name: 'Vendor'},
    {key: 'merchant', name: 'Merchant'}
];

const propMap = {
    country: 'countries',
    region: 'regions',
    city: 'cities',
    operation: 'operations',
    so: 'source',
    do: 'destination',
    co: 'channel',
    ss: 'source',
    ds: 'destination',
    cs: 'channel',
    oc: 'operation',
    sc: 'source',
    dc: 'destination'
};

function prepareRuleModel(dbresult) {
    var condition = (dbresult.condition || [])[0] || {};
    var rule = {
        channel: {
            conditionId: condition.conditionId,
            priority: condition.priority,
            properties: [],
            countries: [],
            cities: [],
            regions: []
        },
        destination: { properties: [], countries: [], cities: [], regions: [] },
        source: { properties: [], countries: [], cities: [], regions: [] },
        split: {
            splits: []
        },
        limit: [],
        operation: {
            operations: [],
            properties: [],
            startDate: condition.operationStartDate,
            endDate: condition.operationEndDate
        }
    };
    (dbresult.conditionActor || []).forEach((ca) => {
        var des = rule[propMap[ca.factor]];
        des && (des[ca.type] = ca.actorId);
    });
    // condition item
    (dbresult.conditionItem || []).forEach((item) => {
        if (['operation', 'country', 'city', 'region'].indexOf(item.type) > -1) {
            var obj = rule[propMap[item.factor]] && rule[propMap[item.factor]][propMap[item.type]];
            obj && obj.push({
                key: item.itemNameId,
                name: item.itemName
            });
        } else {
            rule[propMap[item.factor]] && (rule[propMap[item.factor]][item.type] = item.itemNameId || item.itemName);
        }
    });
    // condition property
    (dbresult.conditionProperty || []).forEach((property) => {
        var obj = rule[propMap[property.factor]];
        obj && obj.properties.push({
            name: property.name,
            value: property.value
        });
    });
    // limit
    dbresult.limit && dbresult.limit.sort((a, b) => a.limitId > b.limitId).forEach((limit) => {
        rule.limit.push({
            conditionId: condition.conditionId,
            limitId: limit.limitId,
            currency: limit.currency,
            txMin: limit.minAmount,
            txMax: limit.maxAmount,
            dailyMaxAmount: limit.maxAmountDaily,
            dailyMaxCount: parseInt(limit.maxCountDaily) || '',
            weeklyMaxAmount: limit.maxAmountWeekly,
            weeklyMaxCount: parseInt(limit.maxCountWeekly) || '',
            monthlyMaxAmount: limit.maxAmountMonthly,
            monthlyMaxCount: parseInt(limit.maxCountMonthly) || ''
        });
    });
    // split
    dbresult.splitName && dbresult.splitName.forEach((splitName) => {
        if (!splitName.name) return;
        let splitNameId = splitName.splitNameId;
        var split = {
            conditionId: condition.conditionId,
            name: splitName.name,
            splitNameId,
            tags: [],
            cumulatives: [],
            assignments: []
        };
        splitName.tag && splitName.tag.split('|').filter((ts) => !!ts).forEach((tagName) => {
            var splitTag = splitTags.find((st) => st.key === tagName);
            splitTag && split.tags.push(splitTag);
        });
        var splitRange = dbresult.splitRange && dbresult.splitRange.filter((range) => range.splitNameId === splitNameId);
        if (splitRange.length > 0) {
            let uniqueCurrencies = []; // ideally its good to split the cumulatives by cumulative id
            var cumulatives = splitRange.filter((cum) => {
                if (cum.startAmountCurrency && uniqueCurrencies.includes(cum.startAmountCurrency)) return false;
                else if (cum.startAmountCurrency) {
                    uniqueCurrencies.push(cum.startAmountCurrency);
                    return true;
                } else return false;
            });
            cumulatives.forEach(function(range) {
                var cumulative = {
                    splitNameId,
                    currency: range.startAmountCurrency,
                    dailyCount: parseInt(range.startCountDaily) || '',
                    dailyAmount: range.startAmountDaily,
                    weeklyCount: parseInt(range.startCountWeekly) || '',
                    weeklyAmount: range.startAmountWeekly,
                    monthlyCount: parseInt(range.startCountMonthly) || '',
                    monthlyAmount: range.startAmountMonthly,
                    ranges: []
                };
                splitRange.forEach((srange) => {
                    range.startAmountCurrency === srange.startAmountCurrency && cumulative.ranges.push({
                        splitRangeId: srange.splitRangeId,
                        startAmount: srange.startAmount,
                        minAmount: srange.minValue,
                        maxAmount: srange.maxValue,
                        percent: srange.percent,
                        isSourceAmount: srange.isSourceAmount
                    });
                });
                split.cumulatives.push(cumulative);
            });
        }
        dbresult.splitAssignment && dbresult.splitAssignment.filter((sa) => sa.splitNameId === splitNameId).forEach((assignment) => {
            split.assignments.push({
                splitNameId: assignment.splitNameId,
                splitAssignmentId: assignment.splitAssignmentId,
                debit: assignment.debit,
                credit: assignment.credit,
                minAmount: assignment.minValue,
                maxAmount: assignment.maxValue,
                percent: assignment.percent,
                description: assignment.description
            });
        });
        rule.split.splits.push(split);
    });
    return rule;
};

module.exports = {
    prepareRuleModel,
    splitTags
};
