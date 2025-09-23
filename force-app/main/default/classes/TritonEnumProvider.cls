public abstract class TritonEnumProvider {

    public abstract class BaseToken {
        public String kind;
        public String value;

        protected BaseToken(String kind, String value) {
            this.kind  = kind;
            this.value = String.isNotBlank(value) ? value.trim().toUpperCase() : null;
        }

        public String v() {
            return this.value;
        }

        public override String toString() {
            return this.value;
        }
    }

    public class AreaEnum extends BaseToken {
        public AreaEnum(String v) {
            super('AREA', v);
        }
    }

    public class TypeEnum extends BaseToken {
        public TypeEnum(String v) {
            super('TYPE', v);
        }
    }

    public class CategoryEnum extends BaseToken {
        public CategoryEnum(String v) {
            super('CATEGORY', v);
        }
    }
}