/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

/**
 * Base class for Triton Enum system in LWC
 * Provides the foundation for extensible enum values
 */
export class TritonEnumProvider {
    
    /**
     * Base token class for all enum values
     */
    static BaseToken = class {
        constructor(kind, value) {
            this.kind = kind;
            this.value = value ? value.trim().toUpperCase() : null;
        }

        /**
         * Get the value of this token
         * @returns {string} The enum value
         */
        v() {
            return this.value;
        }

        /**
         * String representation of the token
         * @returns {string} The enum value
         */
        toString() {
            return this.value;
        }

        /**
         * Check if this token equals another token
         * @param {BaseToken} other - Other token to compare
         * @returns {boolean} True if tokens are equal
         */
        equals(other) {
            return other && this.kind === other.kind && this.value === other.value;
        }
    };

    /**
     * Area enum token
     */
    static AreaEnum = class extends TritonEnumProvider.BaseToken {
        constructor(value) {
            super('AREA', value);
        }
    };

    /**
     * Type enum token
     */
    static TypeEnum = class extends TritonEnumProvider.BaseToken {
        constructor(value) {
            super('TYPE', value);
        }
    };

    /**
     * Category enum token
     */
    static CategoryEnum = class extends TritonEnumProvider.BaseToken {
        constructor(value) {
            super('CATEGORY', value);
        }
    };

    /**
     * Create a new Area enum
     * @param {string} value - The area value
     * @returns {AreaEnum} New area enum instance
     */
    static createArea(value) {
        return new TritonEnumProvider.AreaEnum(value);
    }

    /**
     * Create a new Type enum
     * @param {string} value - The type value
     * @returns {TypeEnum} New type enum instance
     */
    static createType(value) {
        return new TritonEnumProvider.TypeEnum(value);
    }

    /**
     * Create a new Category enum
     * @param {string} value - The category value
     * @returns {CategoryEnum} New category enum instance
     */
    static createCategory(value) {
        return new TritonEnumProvider.CategoryEnum(value);
    }
}
