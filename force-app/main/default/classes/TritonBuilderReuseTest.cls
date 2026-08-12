/**
 * Regression test for TritonBuilder.build() aliasing: the managed builder
 * returns the same sObject instance from every build(), so without the
 * defensive clone in build(), reusing one TritonBuilder across multiple
 * Triton.log() calls makes every buffered record alias the latest build.
 */
@IsTest
private class TritonBuilderReuseTest {

    @IsTest
    static void reusedBuilderBuffersDistinctRecords() {
        Triton.startTransaction();
        TritonBuilder reused = Triton.makeBuilder()
            .category(TritonTypes.Category.Apex)
            .type(TritonTypes.Type.Backend)
            .area(TritonTypes.Area.Community)
            .stackTrace('Class.TritonBuilderReuseTest.run: line 1');

        Triton.log(reused.operation('ReuseTest.first').summary('first record'));
        Triton.log(reused.operation('ReuseTest.second').summary('second record'));

        List<pharos__Log__c> buffered = Triton.drain();
        System.assertEquals(2, buffered.size(), 'two records should be buffered');
        System.assertNotEquals(buffered[0], buffered[1],
            'buffered records must not alias one instance');
        System.assertEquals('first record', buffered[0].pharos__Summary__c,
            'first record must keep its own field values');
        System.assertEquals('second record', buffered[1].pharos__Summary__c,
            'second record must keep its own field values');
    }

    @IsTest
    static void buildTwiceReturnsIndependentRecords() {
        TritonBuilder b = Triton.makeBuilder().summary('one');
        pharos__Log__c first = b.build();
        b.summary('two');
        pharos__Log__c second = b.build();
        System.assertEquals('one', first.pharos__Summary__c,
            'a built record must not be mutated by later builder writes');
        System.assertEquals('two', second.pharos__Summary__c);
    }
}
