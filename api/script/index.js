const prepareHistory = require('../../history/prepare');
const historyConfig = require('../../history/config');
const wrapper = {
    itemName: function(msg, $meta) {
        return this.bus.importMethod('core.itemName.fetch')(msg, $meta);
    },
    itemCode: function(msg, $meta) {
        return this.bus.importMethod('core.itemCode.fetch')(msg, $meta);
    },
    agentRole: function(msg, $meta) {
        return this.bus.importMethod('db/integration.agentRole.fetch')(msg, $meta);
    },
    accountAlias: function(msg, $meta) {
        return this.bus.importMethod('db/integration.alias.list')(msg, $meta);
    },
    organization: function(msg, $meta) {
        return this.bus.importMethod('customer.organization.graphFetch')(msg, $meta).then(result => {
            const organizations = result.organization.filter((obj, position, arr) => {
                return arr.map(mapObj => mapObj.id).indexOf(obj.id) === position;
            });
            return {items: organizations.map(v => ({ type: 'organization', value: v.id, display: v.title }))};
        });
    },
    role: function(msg, $meta) {
        return this.bus.importMethod('user.role.fetch')(msg, $meta).then(result => {
            const role = result.role;
            return {items: role.map(v => ({ type: 'role', value: v.actorId, display: v.name }))};
        });
    }
};

module.exports = function rule() {
    return {
        'rule.item.fetch': function(msg, $meta) {
            const pending = [];

            Object.keys(msg).forEach(function(method) {
                if (wrapper[method] !== undefined && msg[method] && msg[method].length > 0) {
                    const params = {
                        alias: msg[method]
                    };
                    if (msg.skipDisabled && msg.skipDisabled.includes(method)) {
                        params.isEnabled = 1;
                    }
                    pending.push(wrapper[method].call(this, params, Object.assign({}, $meta)));
                }
            }, this);

            return Promise.all(pending).then(function(result) {
                let data = [];

                result.forEach(function(item) {
                    data = data.concat(item[Object.keys(item)[0]]);
                });

                return {items: data};
            });
        },
        'rule.rule.historyTransform': function(msg, $meta) {
            const objectName = 'rule';
            const rule = prepareHistory[objectName] && prepareHistory[objectName](msg.data);
            return this.bus.importMethod('history.history.transform')({
                config: historyConfig[objectName],
                data: rule || {}
            }).then(function(transformedData) {
                return { data: transformedData };
            });
        },
        'rule.rule.add': async function(msg, $meta) {
            const {notification, ...result} = await this.bus.importMethod('db/rule.rule.add')(msg, $meta);
            await this.bus.importMethod('notice.message.push')(notification, $meta);
            return result;
        },
        'rule.rule.edit': async function(msg, $meta) {
            const {notification, ...result} = await this.bus.importMethod('db/rule.rule.edit')(msg, $meta);
            await this.bus.importMethod('notice.message.push')(notification, $meta);
            return result;
        },
        'rule.rule.remove': async function(msg, $meta) {
            const {notification, ...result} = await this.bus.importMethod('db/rule.rule.remove')(msg, $meta);
            await this.bus.importMethod('notice.message.push')(notification, $meta);
            return result;
        }
    };
};
