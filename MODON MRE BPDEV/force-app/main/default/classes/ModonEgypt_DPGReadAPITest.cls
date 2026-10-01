/**********************************************************************************************************************
* Name               : ModonEgypt_DPGReadAPITest
* Description        : Test class for ModonEgypt_DPGReadAPI (DPG Read API). Covers the new dynamic "filters" /
*                      "filterLogic" WHERE condition support, including:
*                      - Single condition filters (=, !=, >, >=, <, LIKE, IN)
*                      - Null value handling (field = null)
*                      - Sequential AND / OR combination via logicalOperator
*                      - Explicit grouping via filterLogic (e.g. "(1 AND 2) OR 3")
*                      - Relationship/lookup field filters (e.g. Owner.Email)
*                      - Validation failures: invalid fieldName, invalid operatorType, missing valueList,
*                        invalid numeric value, invalid filterLogic expression, out-of-range filterLogic index
* Usage              : Executes unit tests to validate DPG dynamic filter behavior and ensure code coverage
* Created By         : Narendra Agrawal (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Narendra Agrawal (Horizontal)      13 AUG 2026     Initial version to test DPG Read API
**********************************************************************************************************************/
@IsTest
public class ModonEgypt_DPGReadAPITest {

    @TestSetup
    static void setupTestData() {
        Phase__c phase = new Phase__c(Name = 'Test Phase');
        insert phase;

        // Create DPG Egypt Unit 1
        Unit__c egyptUnit = new Unit__c(
            Name = 'Egypt Unit A-101',
            PlotNo__c = 'P001',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Phase__c = phase.Id,
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 500000,
            Status__c = 'Available',
            GrossFloorAreaGFA__c = 250,
            Zone__c = 'Yemm Views'
        );
        insert egyptUnit;

        // Create DPG Egypt Unit 2 (Status__c intentionally left null for null-value filter tests)
        Unit__c egyptUnit2 = new Unit__c(
            Name = 'Egypt Unit A-102',
            PlotNo__c = 'P002',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2',
            Phase__c = phase.Id,
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 350000,
            Zone__c = 'Yemm Views'
        );
        insert egyptUnit2;

        // Create UAE Unit (should NOT be returned - Source Entity restriction)
        Unit__c uaeUnit = new Unit__c(
            Name = 'UAE Unit B-101',
            PlotNo__c = 'P003',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '4',
            Source_Entity__c = 'Modon - UAE',
            Zone__c = 'Yemm Views'
        );
        insert uaeUnit;
    }

    private static Map<String,Object> executeAPI(String body) {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/DPGReadAPI';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = res;

        ModonEgypt_DPGReadAPI.getRecords();

        return (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
    }

    // Test single equality filter condition (Status__c = 'Available')
    @IsTest
    static void testFilterEqualsOperator_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name', 'Status__c' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'Status__c',
                    'operatorType' => '=',
                    'value' => 'Available'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(1, response.get('count'));
    }

    // Test "field = null" style filter using the literal "null" value keyword
    @IsTest
    static void testFilterNullValue_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name', 'Status__c' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'Status__c',
                    'operatorType' => '=',
                    'value' => 'null'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(1, response.get('count'));
    }

    // Test numeric comparison operator (BasePrice__c >= 400000)
    @IsTest
    static void testFilterNumericGreaterThanOrEqual_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name', 'BasePrice__c' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'BasePrice__c',
                    'operatorType' => '>=',
                    'value' => '400000'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(1, response.get('count'));
    }

    // Test IN operator with valueList (UnitClassification__c IN ('Villa','Apartment'))
    @IsTest
    static void testFilterInOperator_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name', 'UnitClassification__c' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'UnitClassification__c',
                    'operatorType' => 'IN',
                    'valueList' => new List<String>{ 'Villa', 'Apartment' }
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(2, response.get('count'));
    }

    // Test LIKE operator (Name LIKE '%A-101%')
    @IsTest
    static void testFilterLikeOperator_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'Name',
                    'operatorType' => 'LIKE',
                    'value' => '%A-101%'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(1, response.get('count'));
    }

    // Test sequential AND combination (default logicalOperator) across two conditions
    @IsTest
    static void testFilterSequentialAnd_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'UnitClassification__c',
                    'operatorType' => '=',
                    'value' => 'Villa',
                    'logicalOperator' => 'AND'
                },
                new Map<String,Object>{
                    'fieldName' => 'BasePrice__c',
                    'operatorType' => '>=',
                    'value' => '400000'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(1, response.get('count'));
    }

    // Test sequential OR combination (default logicalOperator) across two conditions
    @IsTest
    static void testFilterSequentialOr_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'UnitClassification__c',
                    'operatorType' => '=',
                    'value' => 'Villa',
                    'logicalOperator' => 'OR'
                },
                new Map<String,Object>{
                    'fieldName' => 'UnitClassification__c',
                    'operatorType' => '=',
                    'value' => 'Apartment'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(2, response.get('count'));
    }

    // Test explicit filterLogic grouping: (1 AND 2) OR 3
    @IsTest
    static void testFilterLogicGrouping_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'BasePrice__c',
                    'operatorType' => '>=',
                    'value' => '400000'
                },
                new Map<String,Object>{
                    'fieldName' => 'UnitClassification__c',
                    'operatorType' => '=',
                    'value' => 'Villa'
                },
                new Map<String,Object>{
                    'fieldName' => 'UnitClassification__c',
                    'operatorType' => '=',
                    'value' => 'Apartment'
                }
            },
            'filterLogic' => '(1 AND 2) OR 3'
        }));

        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(2, response.get('count'));
    }

    // Test relationship/lookup field filter (Owner.Email LIKE '%@%')
    @IsTest
    static void testFilterRelationshipField_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'extraFields' => new List<String>{ 'Owner.Email' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'Owner.Email',
                    'operatorType' => 'LIKE',
                    'value' => '%@%'
                }
            }
        }));

        Test.stopTest();
    }

    // Test validation failure: invalid fieldName (fails regex format check)
    @IsTest
    static void testFilterInvalidFieldName_failure() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'Status__c; DROP',
                    'operatorType' => '=',
                    'value' => 'Available'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(false, response.get('success'));
    }

    // Test validation failure: field does not exist on object
    @IsTest
    static void testFilterFieldDoesNotExist_failure() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'NonExistingField__c',
                    'operatorType' => '=',
                    'value' => 'Available'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(false, response.get('success'));
    }

    // Test validation failure: unsupported operatorType
    @IsTest
    static void testFilterInvalidOperator_failure() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'Status__c',
                    'operatorType' => 'DROP TABLE',
                    'value' => 'Available'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(false, response.get('success'));
    }

    // Test validation failure: IN operator used without valueList
    @IsTest
    static void testFilterInMissingValueList_failure() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'UnitClassification__c',
                    'operatorType' => 'IN'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(false, response.get('success'));
    }

    // Test validation failure: non-numeric value supplied for a numeric field
    @IsTest
    static void testFilterInvalidNumericValue_failure() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'BasePrice__c',
                    'operatorType' => '=',
                    'value' => 'not-a-number'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(false, response.get('success'));
    }

    // Test validation failure: filterLogic contains disallowed characters/tokens
    @IsTest
    static void testFilterLogicInvalidExpression_failure() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'UnitClassification__c',
                    'operatorType' => '=',
                    'value' => 'Villa'
                },
                new Map<String,Object>{
                    'fieldName' => 'BasePrice__c',
                    'operatorType' => '>=',
                    'value' => '400000'
                }
            },
            'filterLogic' => '1 AND DELETE'
        }));

        Test.stopTest();

        System.assertEquals(false, response.get('success'));
    }

    // Test validation failure: filterLogic references an out-of-range condition index
    @IsTest
    static void testFilterLogicOutOfRangeIndex_failure() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'fieldName' => 'UnitClassification__c',
                    'operatorType' => '=',
                    'value' => 'Villa'
                }
            },
            'filterLogic' => '1 AND 5'
        }));

        Test.stopTest();

        System.assertEquals(false, response.get('success'));
    }

    // Test validation failure: filter condition missing both fieldName and operatorType
    @IsTest
    static void testFilterMissingFieldNameAndOperator_failure() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>{
                new Map<String,Object>{
                    'value' => 'Villa'
                }
            }
        }));

        Test.stopTest();

        System.assertEquals(false, response.get('success'));
    }

    // Test no "filters" provided still works as before (backward compatibility)
    @IsTest
    static void testNoFiltersProvided_backwardCompatible_success() {
        Test.startTest();

        Map<String,Object> response = executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'fields' => new List<String>{ 'Id', 'Name' },
            'filters' => new List<Object>()
        }));

        Test.stopTest();

        System.assertEquals(true, response.get('success'));
        System.assertEquals(2, response.get('count'));
    }

	// Test fetching Unit records using requested fields
    @IsTest
    static void testFetchUnitWithCustomFields() {
        Test.startTest();
        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName'=>'Unit__c',
            'fields'=>new List<String>{
                'Id',
                'Name',
                'UnitClassification__c',
                'Phase__c'
            }
        }));

        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );


        System.assertEquals(true,response.get('success'));
        System.assertEquals(2,response.get('count'));
    }

    // Test only Egypt Unit records are returned
    @IsTest
    static void testSourceEntityRestrictionForUnit() {
        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName'=>'Unit__c',
            'fields'=>new List<String>{
                'Name',
                'Source_Entity__c'
            }
        }));

        Test.stopTest();


        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );


        List<Object> records = (List<Object>)response.get('records');
        System.assertEquals(2,records.size());


        for(Object record : records){
            Map<String,Object> data = (Map<String,Object>)record;
            System.assertEquals('Modon - Egypt', data.get('Source_Entity__c'));
        }
    }

    // Test fetching specific Unit using Id filter
    @IsTest
    static void testFetchUnitByIds() {
        Unit__c unit =
            [
                SELECT Id
                FROM Unit__c
                WHERE Name='Egypt Unit A-101'
                LIMIT 1
            ];


        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName'=>'Unit__c',
            'ids'=>new List<String>{unit.Id},
            'fields'=>new List<String>{
                'Id',
                'Name'
            }
        }));

        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );


        System.assertEquals(1,response.get('count'));
    }

    // Test lookup enrichment for relationship field on Unit
    @IsTest
    static void testLookupRelationshipFields() {
        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName'=>'Unit__c',
            'fields'=>new List<String>{
                'Id',
                'Phase__c'    
            }
        }));

        Test.stopTest();


        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );


        System.assertEquals(true,response.get('success'));
    }

    // Test ORDER BY and LIMIT functionality
    @IsTest
    static void testLimitAndSorting() {
        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName'=>'Unit__c',
            'fields'=>new List<String>{
                'Id',
                'Name'
            },
            'sortField'=>'Name',
            'sortDirection'=>'ASC',
            'limitSize'=>1
        }));

        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );

        System.assertEquals(1,response.get('count'));
    }

    // Test invalid object validation
    @IsTest
    static void testInvalidObjectName() {
        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName'=>'InvalidObject__c'
        }));

        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );

        System.assertEquals(false,response.get('success'));
    }

    // Test mandatory objectName validation
    @IsTest
    static void testMissingObjectName() {
        Test.startTest();
        executeAPI('{}');
        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );

        System.assertEquals(false,response.get('success'));
    }

    // Test invalid LastNDays validation when sent negative
    @IsTest
    static void testInvalidLastNDays_failure() {
        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'ids' => new List<String>(),
            'fields' => new List<String>(),
            'extraFields' => new List<String>{
                'Owner.Email'
            },
            'createdDateFrom' => null,
            'createdDateTo' => null,
            'lastModifiedFrom' => null,
            'lastModifiedTo' => null,
            'lastNDays' => -10,
            'dateFilterFieldForLastNDays' => 'LastModifiedDate',
            'sortField' => 'CreatedDate',
            'sortDirection' => 'DESC',
            'limitSize' => 1
        }));

        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );

        System.assertEquals(false,response.get('success'));
    }
    
    // Test invalid dateFilterFieldForLastNDays field
    @IsTest
    static void testInvalidDateFilterFieldForLastNDays_failure() {
        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'ids' => new List<String>(),
            'fields' => new List<String>(),
            'extraFields' => new List<String>{
                'Owner.Email'
            },
            'createdDateFrom' => null,
            'createdDateTo' => null,
            'lastModifiedFrom' => null,
            'lastModifiedTo' => null,
            'lastNDays' => 10,
            'dateFilterFieldForLastNDays' => 'InvalidField__c',   //Pass InValid field
            'sortField' => 'CreatedDate',
            'sortDirection' => 'DESC',
            'limitSize' => 1
        }));

        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );

        System.assertEquals(false,response.get('success'));
    }
    
    // Test dateFilterFieldForLastNDays field of not DateTimeType
    @IsTest
    static void testDateFilterFieldForLastNDays_OtherThanDateTime_failure() {
        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'ids' => new List<String>(),
            'fields' => new List<String>(),
            'extraFields' => new List<String>{
                'Owner.Email'
            },
            'createdDateFrom' => null,
            'createdDateTo' => null,
            'lastModifiedFrom' => null,
            'lastModifiedTo' => null,
            'lastNDays' => 10,
            'dateFilterFieldForLastNDays' => 'Source_Entity__c',   //Pass valid field but not of DateTime type
            'sortField' => 'CreatedDate',
            'sortDirection' => 'DESC',
            'limitSize' => 1
        }));

        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );

        System.assertEquals(false,response.get('success'));
    }
    
    // Test invalid LastNDays validation should not fire when pssing 0 or positive Integer value
    @IsTest
    static void testInvalidLastNDays_success() {
    
        Test.startTest();
    
        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'ids' => new List<String>(),
            'fields' => new List<String>(),
            'extraFields' => new List<String>{
                'Owner.Email'
            },
            'createdDateFrom' => null,
            'createdDateTo' => null,
            'lastModifiedFrom' => null,
            'lastModifiedTo' => null,
            'lastNDays' => 10,
            'dateFilterFieldForLastNDays' => 'LastModifiedDate',
            'sortField' => 'CreatedDate',
            'sortDirection' => 'DESC',
            'limitSize' => 1
        }));
    
        Test.stopTest();
    
    
        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
    }

    // Test data should be fetched based on Created Date From and TO
    @IsTest
    static void testCreatedFrom_CreatedTo_success() {
        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'ids' => new List<String>(),
            'fields' => new List<String>(),
            'extraFields' => new List<String>{
                'Owner.Email'
            },
            'createdDateFrom' => System.now().addDays(-1),
            'createdDateTo' => System.now().addDays(1),
            'lastModifiedFrom' => null,
            'lastModifiedTo' => null,
            'lastNDays' => null,
            'dateFilterFieldForLastNDays' => null,
            'sortField' => 'CreatedDate',
            'sortDirection' => 'DESC',
            'limitSize' => 1
        }));

        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
    }

    // Test data should be fetched based on Last Modified Date From and Last Modified To
    @IsTest
    static void testLastModifiedFrom_LastModifiedTo_success() {
        Test.startTest();

        executeAPI(JSON.serialize(new Map<String,Object>{
            'objectName' => 'Unit__c',
            'ids' => new List<String>(),
            'fields' => new List<String>(),
            'extraFields' => new List<String>{
                'Owner.Email'
            },
            'createdDateFrom' => null,
            'createdDateTo' => null,
            'lastModifiedFrom' => System.now().addDays(-1),
            'lastModifiedTo' => System.now().addDays(1),
            'lastNDays' => null,
            'dateFilterFieldForLastNDays' => null,
            'sortField' => 'CreatedDate',
            'sortDirection' => 'DESC',
            'limitSize' => 1
        }));

        Test.stopTest();

        Map<String,Object> response =
            (Map<String,Object>)
            JSON.deserializeUntyped(
                RestContext.response.responseBody.toString()
            );
    }
}