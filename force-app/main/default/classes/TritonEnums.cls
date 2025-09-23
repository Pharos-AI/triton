public with sharing class TritonEnums extends TritonEnumProvider {

    public static final AreaEnums AREA_ENUMS { 
        get { return AREA_ENUMS == null ? (AREA_ENUMS = new AreaEnums()) : AREA_ENUMS; }
        private set;
    }

    public static final CategoryEnums CATEGORY_ENUMS { 
        get { return CATEGORY_ENUMS == null ? (CATEGORY_ENUMS = new CategoryEnums()) : CATEGORY_ENUMS; }
        private set;
    }

    public static final TypeEnums TYPE_ENUMS { 
        get { return TYPE_ENUMS == null ? (TYPE_ENUMS = new TypeEnums()) : TYPE_ENUMS; }
        private set;
    }

    private static final Boolean IS_SUBSCRIBER_CLASS_EXIST {
        get { return IS_SUBSCRIBER_CLASS_EXIST == null ? (IS_SUBSCRIBER_CLASS_EXIST = isSubscriberClassExist()) : IS_SUBSCRIBER_CLASS_EXIST; }
        private set;
    }

    public static Map<String, AreaEnum> AREA_ENUM_BY_VALUE {
        get {
            if (AREA_ENUM_BY_VALUE == null) {
                AREA_ENUM_BY_VALUE = new Map<String, AreaEnum>{
                    AREA_ENUMS.OPPORTUNITY_MANAGEMENT.v() => AREA_ENUMS.OPPORTUNITY_MANAGEMENT,
                    AREA_ENUMS.LEAD_CONVERSION.v() => AREA_ENUMS.LEAD_CONVERSION,
                    AREA_ENUMS.COMMUNITY.v() => AREA_ENUMS.COMMUNITY,
                    AREA_ENUMS.REST_API.v() => AREA_ENUMS.REST_API,
                    AREA_ENUMS.ACCOUNTS.v() => AREA_ENUMS.ACCOUNTS,
                    AREA_ENUMS.LWC.v() => AREA_ENUMS.LWC,
                    AREA_ENUMS.FLOW.v() => AREA_ENUMS.FLOW
                };

                if (IS_SUBSCRIBER_CLASS_EXIST) {
                    Map<String, AreaEnum> subscriberAreaEnumByValue = subscriber.getAreaByValueMap();
                    if (subscriberAreaEnumByValue != null && !subscriberAreaEnumByValue.isEmpty()) {
                        AREA_ENUM_BY_VALUE.putAll(subscriberAreaEnumByValue);
                    }
                }
            }
            return AREA_ENUM_BY_VALUE;
        }
        private set;
    }

    public static Map<String, CategoryEnum> CATEGORY_ENUM_BY_VALUE {
        get {
            if (CATEGORY_ENUM_BY_VALUE == null) {
                CATEGORY_ENUM_BY_VALUE = new Map<String, CategoryEnum>{
                    CATEGORY_ENUMS.APEX.v() => CATEGORY_ENUMS.APEX,
                    CATEGORY_ENUMS.FLOW.v() => CATEGORY_ENUMS.FLOW,
                    CATEGORY_ENUMS.LWC.v() => CATEGORY_ENUMS.LWC,
                    CATEGORY_ENUMS.AURA.v() => CATEGORY_ENUMS.AURA,
                    CATEGORY_ENUMS.WARNING.v() => CATEGORY_ENUMS.WARNING,
                    CATEGORY_ENUMS.EVENT.v() => CATEGORY_ENUMS.EVENT,
                    CATEGORY_ENUMS.DEBUG.v() => CATEGORY_ENUMS.DEBUG,
                    CATEGORY_ENUMS.INTEGRATION.v() => CATEGORY_ENUMS.INTEGRATION
                };

                if (IS_SUBSCRIBER_CLASS_EXIST) {
                    Map<String, CategoryEnum> subscriberCategoryEnumByValue = subscriber.getCategoryByValueMap();
                    if (subscriberCategoryEnumByValue != null && !subscriberCategoryEnumByValue.isEmpty()) {
                        CATEGORY_ENUM_BY_VALUE.putAll(subscriberCategoryEnumByValue);
                    }
                }
            }
            return CATEGORY_ENUM_BY_VALUE;
        }
        private set;
    }

    public static Map<String, TypeEnum> TYPE_ENUM_BY_VALUE {
        get {
            if (TYPE_ENUM_BY_VALUE == null) {
                TYPE_ENUM_BY_VALUE = new Map<String, TypeEnum>{
                    TYPE_ENUMS.BACKEND.v() => TYPE_ENUMS.BACKEND,
                    TYPE_ENUMS.FRONTEND.v() => TYPE_ENUMS.FRONTEND,
                    TYPE_ENUMS.DML_RESULT.v() => TYPE_ENUMS.DML_RESULT,
                    TYPE_ENUMS.LONG_RUNNING_REQUEST.v() => TYPE_ENUMS.LONG_RUNNING_REQUEST,
                    TYPE_ENUMS.CONCURRENT_REQUEST_LIMIT.v() => TYPE_ENUMS.CONCURRENT_REQUEST_LIMIT,
                    TYPE_ENUMS.ACCOUNT_TRIGGER.v() => TYPE_ENUMS.ACCOUNT_TRIGGER
                };

                if (IS_SUBSCRIBER_CLASS_EXIST) {
                    Map<String, TypeEnum> subscriberTypeEnumByValue = subscriber.getTypeByValueMap();
                    if (subscriberTypeEnumByValue != null && !subscriberTypeEnumByValue.isEmpty()) {
                        TYPE_ENUM_BY_VALUE.putAll(subscriberTypeEnumByValue);
                    }
                }
            }
            return TYPE_ENUM_BY_VALUE;
        }
        private set;
    }

    private static ITritonEnumsSubscriber subscriber;

    public static AreaEnum getAreaEnum(String value) {
        return new AreaEnum(value);
    }

    public static CategoryEnum getCategoryEnum(String value) {
        return new CategoryEnum(value);
    }

    public static TypeEnum getTypeEnum(String value) {
        return new TypeEnum(value);
    }

    private static Boolean isSubscriberClassExist() {
        Type t = Type.forName('TritonEnumsSubscriber');
        if (t == null) return false;

        Object o = t.newInstance();
        if (o instanceof ITritonEnumsSubscriber) {
            subscriber = (ITritonEnumsSubscriber) o;
            return true;
        }
        return false;
    }

    public inherited sharing class AreaEnums {
        public final AreaEnum OPPORTUNITY_MANAGEMENT = new AreaEnum('OpportunityManagement');
        public final AreaEnum LEAD_CONVERSION = new AreaEnum('LeadConversion');
        public final AreaEnum COMMUNITY = new AreaEnum('Community');
        public final AreaEnum REST_API = new AreaEnum('RestAPI');
        public final AreaEnum ACCOUNTS = new AreaEnum('Accounts');
        public final AreaEnum LWC = new AreaEnum('LWC');
        public final AreaEnum FLOW = new AreaEnum('Flow');
    }

    public inherited sharing class CategoryEnums {
        public final CategoryEnum APEX = new CategoryEnum('Apex');
        public final CategoryEnum FLOW = new CategoryEnum('Flow');
        public final CategoryEnum LWC = new CategoryEnum('LWC');
        public final CategoryEnum AURA = new CategoryEnum('Aura');
        public final CategoryEnum WARNING = new CategoryEnum('Warning');
        public final CategoryEnum EVENT = new CategoryEnum('Event');
        public final CategoryEnum DEBUG = new CategoryEnum('Debug');
        public final CategoryEnum INTEGRATION = new CategoryEnum('Integration');
    }

    public inherited sharing class TypeEnums {
        public final TypeEnum BACKEND = new TypeEnum('Backend');
        public final TypeEnum FRONTEND = new TypeEnum('Frontend');
        public final TypeEnum DML_RESULT = new TypeEnum('DMLResult');
        public final TypeEnum LONG_RUNNING_REQUEST = new TypeEnum('LongRunningRequest');
        public final TypeEnum CONCURRENT_REQUEST_LIMIT = new TypeEnum('ConcurrentRequestsLimit');
        public final TypeEnum ACCOUNT_TRIGGER = new TypeEnum('AccountTrigger');
    }
}