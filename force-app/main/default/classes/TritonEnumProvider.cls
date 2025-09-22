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

    public class Area extends BaseToken {
        public Area(String v) {
            super('AREA', v);
        }
    }

    public class Type extends BaseToken {
        public Type(String v) {
            super('TYPE', v);
        }
    }

    public class Category extends BaseToken {
        public Category(String v) {
            super('CATEGORY', v);
        }
    }

    public class Level extends BaseToken {
        public Level(String v) {
            super('LEVEL', v);
        }
    }
}