public interface ITritonEnumsSubscriber {
    Map<String, TritonEnumProvider.AreaEnum> getAreaByValueMap();
    Map<String, TritonEnumProvider.CategoryEnum> getCategoryByValueMap();
    Map<String, TritonEnumProvider.TypeEnum> getTypeByValueMap();
}