/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import { ITritonEnumSubscriber } from 'c/tritonEnumSubscriber';
import { TritonEnumProvider } from 'c/tritonEnumProvider';

/**
 * Example custom enum subscriber
 * This demonstrates how users can extend Triton enums with their own values
 */
export class CustomEnumSubscriber extends ITritonEnumSubscriber {
    
    /**
     * Get custom area enums
     * @returns {Map<string, TritonEnumProvider.AreaEnum>} Map of custom area values
     */
    getAreaByValueMap() {
        return new Map([
            ['CUSTOM_SALES', new TritonEnumProvider.AreaEnum('CustomSales')],
            ['CUSTOM_MARKETING', new TritonEnumProvider.AreaEnum('CustomMarketing')],
            ['CUSTOM_SUPPORT', new TritonEnumProvider.AreaEnum('CustomSupport')],
            ['CUSTOM_ANALYTICS', new TritonEnumProvider.AreaEnum('CustomAnalytics')]
        ]);
    }

    /**
     * Get custom type enums
     * @returns {Map<string, TritonEnumProvider.TypeEnum>} Map of custom type values
     */
    getTypeByValueMap() {
        return new Map([
            ['CUSTOM_API', new TritonEnumProvider.TypeEnum('CustomAPI')],
            ['CUSTOM_BATCH', new TritonEnumProvider.TypeEnum('CustomBatch')],
            ['CUSTOM_SCHEDULED', new TritonEnumProvider.TypeEnum('CustomScheduled')],
            ['CUSTOM_INTEGRATION', new TritonEnumProvider.TypeEnum('CustomIntegration')]
        ]);
    }

    /**
     * Get custom category enums
     * @returns {Map<string, TritonEnumProvider.CategoryEnum>} Map of custom category values
     */
    getCategoryByValueMap() {
        return new Map([
            ['CUSTOM_BUSINESS', new TritonEnumProvider.CategoryEnum('CustomBusiness')],
            ['CUSTOM_TECHNICAL', new TritonEnumProvider.CategoryEnum('CustomTechnical')],
            ['CUSTOM_USER', new TritonEnumProvider.CategoryEnum('CustomUser')],
            ['CUSTOM_SYSTEM', new TritonEnumProvider.CategoryEnum('CustomSystem')]
        ]);
    }

    /**
     * Get custom level enums
     * @returns {Map<string, TritonEnumProvider.LevelEnum>} Map of custom level values
     */
    getLevelByValueMap() {
        return new Map([
            ['CUSTOM_TRACE', new TritonEnumProvider.LevelEnum('CUSTOM_TRACE')],
            ['CUSTOM_VERBOSE', new TritonEnumProvider.LevelEnum('CUSTOM_VERBOSE')]
        ]);
    }

    /**
     * Get subscriber name
     * @returns {string} Name of the subscriber
     */
    getSubscriberName() {
        return 'CustomEnumSubscriber';
    }

    /**
     * Get subscriber version
     * @returns {string} Version of the subscriber
     */
    getSubscriberVersion() {
        return '1.0.0';
    }
}

/**
 * Another example subscriber for different organization
 */
export class EnterpriseEnumSubscriber extends ITritonEnumSubscriber {
    
    getAreaByValueMap() {
        return new Map([
            ['ENTERPRISE_CRM', new TritonEnumProvider.AreaEnum('EnterpriseCRM')],
            ['ENTERPRISE_ERP', new TritonEnumProvider.AreaEnum('EnterpriseERP')],
            ['ENTERPRISE_BI', new TritonEnumProvider.AreaEnum('EnterpriseBI')]
        ]);
    }

    getTypeByValueMap() {
        return new Map([
            ['ENTERPRISE_WORKFLOW', new TritonEnumProvider.TypeEnum('EnterpriseWorkflow')],
            ['ENTERPRISE_REPORTING', new TritonEnumProvider.TypeEnum('EnterpriseReporting')]
        ]);
    }

    getCategoryByValueMap() {
        return new Map([
            ['ENTERPRISE_DATA', new TritonEnumProvider.CategoryEnum('EnterpriseData')],
            ['ENTERPRISE_SECURITY', new TritonEnumProvider.CategoryEnum('EnterpriseSecurity')]
        ]);
    }

    getLevelByValueMap() {
        return new Map([
            ['ENTERPRISE_AUDIT', new TritonEnumProvider.LevelEnum('ENTERPRISE_AUDIT')]
        ]);
    }

    getSubscriberName() {
        return 'EnterpriseEnumSubscriber';
    }

    getSubscriberVersion() {
        return '2.0.0';
    }
}
