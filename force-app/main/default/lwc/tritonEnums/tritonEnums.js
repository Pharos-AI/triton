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
import { ITritonEnumSubscriber } from 'c/tritonEnumSubscriber';

/**
 * Main Triton Enums class for LWC
 * Provides default enum values and allows extension through subscribers
 */
export class TritonEnums {
    
    // Static maps to cache enum values
    static _areaEnumByValue = null;
    static _typeEnumByValue = null;
    static _categoryEnumByValue = null;
    static _subscribers = new Set();
    static _subscribersLoaded = false;

    /**
     * Default Area Enums
     */
    static AreaEnums = class {
        static OPPORTUNITY_MANAGEMENT = new TritonEnumProvider.AreaEnum('OpportunityManagement');
        static LEAD_CONVERSION = new TritonEnumProvider.AreaEnum('LeadConversion');
        static COMMUNITY = new TritonEnumProvider.AreaEnum('Community');
        static REST_API = new TritonEnumProvider.AreaEnum('RestAPI');
        static ACCOUNTS = new TritonEnumProvider.AreaEnum('Accounts');
        static LWC = new TritonEnumProvider.AreaEnum('LWC');
        static FLOW = new TritonEnumProvider.AreaEnum('Flow');
    };

    /**
     * Default Type Enums
     */
    static TypeEnums = class {
        static BACKEND = new TritonEnumProvider.TypeEnum('Backend');
        static FRONTEND = new TritonEnumProvider.TypeEnum('Frontend');
        static DML_RESULT = new TritonEnumProvider.TypeEnum('DMLResult');
        static LONG_RUNNING_REQUEST = new TritonEnumProvider.TypeEnum('LongRunningRequest');
        static CONCURRENT_REQUEST_LIMIT = new TritonEnumProvider.TypeEnum('ConcurrentRequestsLimit');
        static ACCOUNT_TRIGGER = new TritonEnumProvider.TypeEnum('AccountTrigger');
    };

    /**
     * Default Category Enums
     */
    static CategoryEnums = class {
        static APEX = new TritonEnumProvider.CategoryEnum('Apex');
        static FLOW = new TritonEnumProvider.CategoryEnum('Flow');
        static LWC = new TritonEnumProvider.CategoryEnum('LWC');
        static AURA = new TritonEnumProvider.CategoryEnum('Aura');
        static WARNING = new TritonEnumProvider.CategoryEnum('Warning');
        static EVENT = new TritonEnumProvider.CategoryEnum('Event');
        static DEBUG = new TritonEnumProvider.CategoryEnum('Debug');
        static INTEGRATION = new TritonEnumProvider.CategoryEnum('Integration');
    };

    /**
     * Get all area enums (default + custom)
     * @returns {Map<string, TritonEnumProvider.AreaEnum>} Map of area values to enum instances
     */
    static getAreaByValueMap() {
        if (!TritonEnums._areaEnumByValue) {
            TritonEnums._loadSubscribers();
            
            TritonEnums._areaEnumByValue = new Map([
                [TritonEnums.AreaEnums.OPPORTUNITY_MANAGEMENT.v(), TritonEnums.AreaEnums.OPPORTUNITY_MANAGEMENT],
                [TritonEnums.AreaEnums.LEAD_CONVERSION.v(), TritonEnums.AreaEnums.LEAD_CONVERSION],
                [TritonEnums.AreaEnums.COMMUNITY.v(), TritonEnums.AreaEnums.COMMUNITY],
                [TritonEnums.AreaEnums.REST_API.v(), TritonEnums.AreaEnums.REST_API],
                [TritonEnums.AreaEnums.ACCOUNTS.v(), TritonEnums.AreaEnums.ACCOUNTS],
                [TritonEnums.AreaEnums.LWC.v(), TritonEnums.AreaEnums.LWC],
                [TritonEnums.AreaEnums.FLOW.v(), TritonEnums.AreaEnums.FLOW]
            ]);

            // Add custom enums from subscribers
            TritonEnums._subscribers.forEach(subscriber => {
                try {
                    const customAreas = subscriber.getAreaByValueMap();
                    if (customAreas && customAreas instanceof Map) {
                        customAreas.forEach((enumValue, key) => {
                            TritonEnums._areaEnumByValue.set(key, enumValue);
                        });
                    }
                } catch (error) {
                    console.warn(`Error loading area enums from subscriber ${subscriber.getSubscriberName()}:`, error);
                }
            });
        }
        return TritonEnums._areaEnumByValue;
    }

    /**
     * Get all type enums (default + custom)
     * @returns {Map<string, TritonEnumProvider.TypeEnum>} Map of type values to enum instances
     */
    static getTypeByValueMap() {
        if (!TritonEnums._typeEnumByValue) {
            TritonEnums._loadSubscribers();
            
            TritonEnums._typeEnumByValue = new Map([
                [TritonEnums.TypeEnums.BACKEND.v(), TritonEnums.TypeEnums.BACKEND],
                [TritonEnums.TypeEnums.FRONTEND.v(), TritonEnums.TypeEnums.FRONTEND],
                [TritonEnums.TypeEnums.DML_RESULT.v(), TritonEnums.TypeEnums.DML_RESULT],
                [TritonEnums.TypeEnums.LONG_RUNNING_REQUEST.v(), TritonEnums.TypeEnums.LONG_RUNNING_REQUEST],
                [TritonEnums.TypeEnums.CONCURRENT_REQUEST_LIMIT.v(), TritonEnums.TypeEnums.CONCURRENT_REQUEST_LIMIT],
                [TritonEnums.TypeEnums.ACCOUNT_TRIGGER.v(), TritonEnums.TypeEnums.ACCOUNT_TRIGGER]
            ]);

            // Add custom enums from subscribers
            TritonEnums._subscribers.forEach(subscriber => {
                try {
                    const customTypes = subscriber.getTypeByValueMap();
                    if (customTypes && customTypes instanceof Map) {
                        customTypes.forEach((enumValue, key) => {
                            TritonEnums._typeEnumByValue.set(key, enumValue);
                        });
                    }
                } catch (error) {
                    console.warn(`Error loading type enums from subscriber ${subscriber.getSubscriberName()}:`, error);
                }
            });
        }
        return TritonEnums._typeEnumByValue;
    }

    /**
     * Get all category enums (default + custom)
     * @returns {Map<string, TritonEnumProvider.CategoryEnum>} Map of category values to enum instances
     */
    static getCategoryByValueMap() {
        if (!TritonEnums._categoryEnumByValue) {
            TritonEnums._loadSubscribers();
            
            TritonEnums._categoryEnumByValue = new Map([
                [TritonEnums.CategoryEnums.APEX.v(), TritonEnums.CategoryEnums.APEX],
                [TritonEnums.CategoryEnums.FLOW.v(), TritonEnums.CategoryEnums.FLOW],
                [TritonEnums.CategoryEnums.LWC.v(), TritonEnums.CategoryEnums.LWC],
                [TritonEnums.CategoryEnums.AURA.v(), TritonEnums.CategoryEnums.AURA],
                [TritonEnums.CategoryEnums.WARNING.v(), TritonEnums.CategoryEnums.WARNING],
                [TritonEnums.CategoryEnums.EVENT.v(), TritonEnums.CategoryEnums.EVENT],
                [TritonEnums.CategoryEnums.DEBUG.v(), TritonEnums.CategoryEnums.DEBUG],
                [TritonEnums.CategoryEnums.INTEGRATION.v(), TritonEnums.CategoryEnums.INTEGRATION]
            ]);

            // Add custom enums from subscribers
            TritonEnums._subscribers.forEach(subscriber => {
                try {
                    const customCategories = subscriber.getCategoryByValueMap();
                    if (customCategories && customCategories instanceof Map) {
                        customCategories.forEach((enumValue, key) => {
                            TritonEnums._categoryEnumByValue.set(key, enumValue);
                        });
                    }
                } catch (error) {
                    console.warn(`Error loading category enums from subscriber ${subscriber.getSubscriberName()}:`, error);
                }
            });
        }
        return TritonEnums._categoryEnumByValue;
    }

    /**
     * Register a subscriber to extend enum values
     * @param {ITritonEnumSubscriber} subscriber - Subscriber instance
     */
    static registerSubscriber(subscriber) {
        if (subscriber instanceof ITritonEnumSubscriber) {
            TritonEnums._subscribers.add(subscriber);
            // Clear cached maps to force reload with new subscriber
            TritonEnums._clearCache();
            console.log(`Registered enum subscriber: ${subscriber.getSubscriberName()} v${subscriber.getSubscriberVersion()}`);
        } else {
            console.error('Subscriber must implement ITritonEnumSubscriber interface');
        }
    }

    /**
     * Unregister a subscriber
     * @param {ITritonEnumSubscriber} subscriber - Subscriber instance to remove
     */
    static unregisterSubscriber(subscriber) {
        if (TritonEnums._subscribers.has(subscriber)) {
            TritonEnums._subscribers.delete(subscriber);
            TritonEnums._clearCache();
            console.log(`Unregistered enum subscriber: ${subscriber.getSubscriberName()}`);
        }
    }

    /**
     * Get all registered subscribers
     * @returns {Set<ITritonEnumSubscriber>} Set of registered subscribers
     */
    static getSubscribers() {
        return new Set(TritonEnums._subscribers);
    }

    /**
     * Clear cached enum maps
     */
    static _clearCache() {
        TritonEnums._areaEnumByValue = null;
        TritonEnums._typeEnumByValue = null;
        TritonEnums._categoryEnumByValue = null;
    }

    /**
     * Load subscribers from global registry
     */
    static _loadSubscribers() {
        if (TritonEnums._subscribersLoaded) {
            return;
        }

        // Try to load subscribers from global registry
        if (typeof window !== 'undefined' && window.TritonEnumSubscribers) {
            window.TritonEnumSubscribers.forEach(subscriberClass => {
                try {
                    const subscriber = new subscriberClass();
                    TritonEnums.registerSubscriber(subscriber);
                } catch (error) {
                    console.warn('Error loading enum subscriber:', error);
                }
            });
        }

        TritonEnums._subscribersLoaded = true;
    }

    /**
     * Get area enum by value
     * @param {string} value - Area value
     * @returns {TritonEnumProvider.AreaEnum|null} Area enum or null if not found
     */
    static getAreaEnum(value) {
        const areaMap = TritonEnums.getAreaByValueMap();
        return areaMap.get(value?.toUpperCase()) || null;
    }

    /**
     * Get type enum by value
     * @param {string} value - Type value
     * @returns {TritonEnumProvider.TypeEnum|null} Type enum or null if not found
     */
    static getTypeEnum(value) {
        const typeMap = TritonEnums.getTypeByValueMap();
        return typeMap.get(value?.toUpperCase()) || null;
    }

    /**
     * Get category enum by value
     * @param {string} value - Category value
     * @returns {TritonEnumProvider.CategoryEnum|null} Category enum or null if not found
     */
    static getCategoryEnum(value) {
        const categoryMap = TritonEnums.getCategoryByValueMap();
        return categoryMap.get(value?.toUpperCase()) || null;
    }

    /**
     * Create a new area enum
     * @param {string} value - Area value
     * @returns {TritonEnumProvider.AreaEnum} New area enum
     */
    static createArea(value) {
        return TritonEnumProvider.createArea(value);
    }

    /**
     * Create a new type enum
     * @param {string} value - Type value
     * @returns {TritonEnumProvider.TypeEnum} New type enum
     */
    static createType(value) {
        return TritonEnumProvider.createType(value);
    }

    /**
     * Create a new category enum
     * @param {string} value - Category value
     * @returns {TritonEnumProvider.CategoryEnum} New category enum
     */
    static createCategory(value) {
        return TritonEnumProvider.createCategory(value);
    }
}
