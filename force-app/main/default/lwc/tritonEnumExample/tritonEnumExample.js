/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

import { LightningElement } from 'lwc';
import { TritonEnums } from 'c/tritonEnums';
import { CustomEnumSubscriber, EnterpriseEnumSubscriber } from 'c/customEnumSubscriber';

/**
 * Example LWC component demonstrating Triton Enum system usage
 */
export default class TritonEnumExample extends LightningElement {
    
    // Default enum values
    defaultAreas = [];
    defaultTypes = [];
    defaultCategories = [];

    // Extended enum values (default + custom)
    extendedAreas = [];
    extendedTypes = [];
    extendedCategories = [];

    // Subscriber info
    subscribers = [];

    connectedCallback() {
        this.loadDefaultEnums();
        this.loadExtendedEnums();
        this.loadSubscriberInfo();
    }

    /**
     * Load default enum values
     */
    loadDefaultEnums() {
        // Load default areas
        const areaMap = TritonEnums.getAreaByValueMap();
        this.defaultAreas = Array.from(areaMap.entries()).map(([key, value]) => ({
            key,
            value: value.v(),
            kind: value.kind
        }));

        // Load default types
        const typeMap = TritonEnums.getTypeByValueMap();
        this.defaultTypes = Array.from(typeMap.entries()).map(([key, value]) => ({
            key,
            value: value.v(),
            kind: value.kind
        }));

        // Load default categories
        const categoryMap = TritonEnums.getCategoryByValueMap();
        this.defaultCategories = Array.from(categoryMap.entries()).map(([key, value]) => ({
            key,
            value: value.v(),
            kind: value.kind
        }));
    }

    /**
     * Load extended enum values (with custom subscribers)
     */
    loadExtendedEnums() {
        // Register custom subscribers
        const customSubscriber = new CustomEnumSubscriber();
        const enterpriseSubscriber = new EnterpriseEnumSubscriber();
        
        TritonEnums.registerSubscriber(customSubscriber);
        TritonEnums.registerSubscriber(enterpriseSubscriber);

        // Clear cache to force reload with subscribers
        TritonEnums._clearCache();

        // Load extended areas
        const extendedAreaMap = TritonEnums.getAreaByValueMap();
        this.extendedAreas = Array.from(extendedAreaMap.entries()).map(([key, value]) => ({
            key,
            value: value.v(),
            kind: value.kind
        }));

        // Load extended types
        const extendedTypeMap = TritonEnums.getTypeByValueMap();
        this.extendedTypes = Array.from(extendedTypeMap.entries()).map(([key, value]) => ({
            key,
            value: value.v(),
            kind: value.kind
        }));

        // Load extended categories
        const extendedCategoryMap = TritonEnums.getCategoryByValueMap();
        this.extendedCategories = Array.from(extendedCategoryMap.entries()).map(([key, value]) => ({
            key,
            value: value.v(),
            kind: value.kind
        }));
    }

    /**
     * Load subscriber information
     */
    loadSubscriberInfo() {
        const subscribers = TritonEnums.getSubscribers();
        this.subscribers = Array.from(subscribers).map(subscriber => ({
            name: subscriber.getSubscriberName(),
            version: subscriber.getSubscriberVersion()
        }));
    }

    /**
     * Handle enum selection
     */
    handleEnumSelection(event) {
        const selectedValue = event.target.value;
        const enumType = event.target.dataset.type;
        
        let selectedEnum = null;
        switch (enumType) {
            case 'area':
                selectedEnum = TritonEnums.getAreaEnum(selectedValue);
                break;
            case 'type':
                selectedEnum = TritonEnums.getTypeEnum(selectedValue);
                break;
            case 'category':
                selectedEnum = TritonEnums.getCategoryEnum(selectedValue);
                break;
        }

        if (selectedEnum) {
            console.log(`Selected ${enumType}:`, {
                value: selectedEnum.v(),
                kind: selectedEnum.kind
            });
        }
    }

    /**
     * Create new enum dynamically
     */
    handleCreateEnum(event) {
        const enumType = event.target.dataset.type;
        const enumValue = prompt(`Enter ${enumType} value:`);
        
        if (enumValue) {
            let newEnum = null;
            switch (enumType) {
                case 'area':
                    newEnum = TritonEnums.createArea(enumValue);
                    break;
                case 'type':
                    newEnum = TritonEnums.createType(enumValue);
                    break;
                case 'category':
                    newEnum = TritonEnums.createCategory(enumValue);
                    break;
            }

            if (newEnum) {
                console.log(`Created new ${enumType}:`, {
                    value: newEnum.v(),
                    kind: newEnum.kind
                });
                
                // Refresh the lists
                this.loadExtendedEnums();
            }
        }
    }
}
