public with sharing class TritonEnums extends TritonEnumProvider {

    public static final AreaEnums AREA { 
        get { return AREA == null ? (AREA = new AreaEnums()) : AREA; }
        private set;
    }

    public static final CategoryEnums CATEGORY { 
        get { return CATEGORY == null ? (CATEGORY = new CategoryEnums()) : CATEGORY; }
        private set;
    }

    public static final TypeEnums TYPE { 
        get { return TYPE == null ? (TYPE = new TypeEnums()) : TYPE; }
        private set;
    }

    public static Area getAreaEnum(String value) {
        return new Area(value);
    }

    public static Category getCategoryEnum(String value) {
        return new Category(value);
    }

    public static Type getTypeEnum(String value) {
        return new Type(value);
    }

    public inherited sharing class AreaEnums {
        public final Area OPPORTUNITY_MANAGEMENT = new Area('OpportunityManagement');
        public final Area LEAD_CONVERSION = new Area('LeadConversion');
        public final Area COMMUNITY = new Area('Community');
        public final Area REST_API = new Area('RestAPI');
        public final Area ACCOUNTS = new Area('Accounts');
        public final Area LWC = new Area('LWC');
        public final Area FLOW = new Area('Flow');

        public final Map<String, Area> AREA_BY_VALUE = new Map<String, Area>{
            OPPORTUNITY_MANAGEMENT.v() => OPPORTUNITY_MANAGEMENT,
            LEAD_CONVERSION.v() => LEAD_CONVERSION,
            COMMUNITY.v() => COMMUNITY,
            REST_API.v() => REST_API,
            ACCOUNTS.v() => ACCOUNTS,
            LWC.v() => LWC,
            FLOW.v() => FLOW
        };
    }

    public inherited sharing class CategoryEnums {
        public final Category APEX = new Category('Apex');
        public final Category FLOW = new Category('Flow');
        public final Category LWC = new Category('LWC');
        public final Category AURA = new Category('Aura');
        public final Category WARNING = new Category('Warning');
        public final Category EVENT = new Category('Event');
        public final Category DEBUG = new Category('Debug');
        public final Category INTEGRATION = new Category('Integration');

        public final Map<String, Category> CATEGORY_BY_VALUE = new Map<String, Category>{
            APEX.v() => APEX,
            FLOW.v() => FLOW,
            LWC.v() => LWC,
            AURA.v() => AURA,
            WARNING.v() => WARNING,
            EVENT.v() => EVENT,
            DEBUG.v() => DEBUG,
            INTEGRATION.v() => INTEGRATION
        };
    }

    public inherited sharing class TypeEnums {
        public final Type BACKEND = new Type('Backend');
        public final Type FRONTEND = new Type('Frontend');
        public final Type DML_RESULT = new Type('DMLResult');
        public final Type LONG_RUNNING_REQUEST = new Type('LongRunningRequest');
        public final Type CONCURRENT_REQUEST_LIMIT = new Type('ConcurrentRequestsLimit');
        public final Type ACCOUNT_TRIGGER = new Type('AccountTrigger');

        public final Map<String, Type> TYPE_BY_VALUE = new Map<String, Type>{
            BACKEND.v() => BACKEND,
            FRONTEND.v() => FRONTEND,
            DML_RESULT.v() => DML_RESULT,
            LONG_RUNNING_REQUEST.v() => LONG_RUNNING_REQUEST,
            CONCURRENT_REQUEST_LIMIT.v() => CONCURRENT_REQUEST_LIMIT,
            ACCOUNT_TRIGGER.v() => ACCOUNT_TRIGGER
        };
    }
}