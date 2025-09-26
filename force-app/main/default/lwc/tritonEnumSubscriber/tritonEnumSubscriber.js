/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import { TritonEnumProvider } from 'c/tritonEnumProvider';

/**
 * Interface for extending Triton Enums in LWC
 * Users can implement this interface to add custom enum values
 */
export class ITritonEnumSubscriber {
    
    /**
     * Get custom area enums
     * @returns {Map<string, TritonEnumProvider.AreaEnum>} Map of area values to enum instances
     */
    getAreaByValueMap() {
        throw new Error('getAreaByValueMap() must be implemented by the subscriber');
    }

    /**
     * Get custom type enums
     * @returns {Map<string, TritonEnumProvider.TypeEnum>} Map of type values to enum instances
     */
    getTypeByValueMap() {
        throw new Error('getTypeByValueMap() must be implemented by the subscriber');
    }

    /**
     * Get custom category enums
     * @returns {Map<string, TritonEnumProvider.CategoryEnum>} Map of category values to enum instances
     */
    getCategoryByValueMap() {
        throw new Error('getCategoryByValueMap() must be implemented by the subscriber');
    }

    /**
     * Get subscriber name for identification
     * @returns {string} Name of the subscriber
     */
    getSubscriberName() {
        return 'UnknownSubscriber';
    }

    /**
     * Get subscriber version
     * @returns {string} Version of the subscriber
     */
    getSubscriberVersion() {
        return '1.0.0';
    }
}
