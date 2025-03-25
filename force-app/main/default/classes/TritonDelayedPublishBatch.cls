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
 * Batch class for delayed log publishing when platform event limits are near capacity.
 * Implements exponential backoff strategy for retries.
 * Uses a singleton pattern to ensure only one batch job is running at a time.
 */
global class TritonDelayedPublishBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    // Static queue to hold loggers that need to be flushed
    @TestVisible
    private static List<pharos.Logger> loggerQueue = new List<pharos.Logger>();
    
    // Flag to track if a batch job is currently running
    private static Boolean isBatchRunning = false;
    
    // ID of the currently running batch job
    private static Id currentBatchId;
    
    // Retry tracking
    private Integer retryCount;
    private Integer maxRetries = 3;
    private Integer baseDelayMinutes = 60; // 1 hour initial delay
    
    // Loggers to process in this batch execution
    private List<pharos.Logger> loggersToProcess;
    
    /**
     * Constructor that takes a retry count
     * @param retryCount The current retry count (0 for first attempt)
     */
    public TritonDelayedPublishBatch(Integer retryCount) {
        this.retryCount = retryCount;
        
        // If this is a new batch (not a retry), copy the current queue
        if (retryCount == 0) {
            this.loggersToProcess = new List<pharos.Logger>(loggerQueue);
            // Clear the static queue for new additions
            loggerQueue.clear();
        } else {
            // For retries, loggersToProcess will be set by the previous batch
            // before scheduling the next attempt
            if (this.loggersToProcess == null) {
                this.loggersToProcess = new List<pharos.Logger>();
            }
        }
    }
    
    /**
     * Constructor that takes a retry count and loggers to process
     * Used for scheduling retries with specific failed loggers
     * @param retryCount The current retry count
     * @param loggersToRetry The loggers that failed and need to be retried
     */
    public TritonDelayedPublishBatch(Integer retryCount, List<pharos.Logger> loggersToRetry) {
        this.retryCount = retryCount;
        this.loggersToProcess = loggersToRetry != null ? loggersToRetry : new List<pharos.Logger>();
    }
    
    /**
     * Adds a logger to the queue and schedules a batch job if one is not already running
     * @param logger The logger to add to the queue
     * @return Boolean True if a new batch was scheduled, false if added to existing queue
     */
    public static Boolean addToQueue(pharos.Logger logger) {
        // Add the logger to the queue
        loggerQueue.add(logger);
        
        // If a batch is not already running, schedule one
        if (!isBatchRunning) {
            scheduleBatch();
            return true;
        }
        
        return false;
    }
    
    /**
     * Schedules a new batch job
     */
    private static void scheduleBatch() {
        if (!loggerQueue.isEmpty()) {
            TritonDelayedPublishBatch batch = new TritonDelayedPublishBatch(0);
            currentBatchId = Database.executeBatch(batch, 1);
            isBatchRunning = true;
        }
    }
    
    /**
     * Start method - returns an empty list as we're not processing any records
     * We're just using the batch framework for scheduling
     */
    global Iterable<SObject> start(Database.BatchableContext bc) {
        // Return empty list - we're not processing any records
        return new List<SObject>();
    }
    
    /**
     * Execute method - attempts to publish logs if platform event limits allow
     */
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        // Check if we're still above threshold
        if (TritonHelper.isPlatformEventAllocationNearThreshold() && !Test.isRunningTest()) {
            if (retryCount < maxRetries) {
                scheduleNextAttempt();
            } else {
                // If we've reached max retries, logs will be lost
                // Reset the batch running flag so new logs can be scheduled
                isBatchRunning = false;
            }
            return;
        }
        
        // If we're below threshold, attempt to publish logs
        List<pharos.Logger> successfulLoggers = new List<pharos.Logger>();
        List<pharos.Logger> failedLoggers = new List<pharos.Logger>();
        
        // Process each logger
        for (pharos.Logger logger : loggersToProcess) {
            try {
                logger.flush();
                successfulLoggers.add(logger);
            } catch (Exception e) {
                failedLoggers.add(logger);
            }
        }
        
        // If there are failed loggers and we haven't reached max retries, schedule another attempt
        if (!failedLoggers.isEmpty() && retryCount < maxRetries) {
            // Only retry the failed loggers
            loggersToProcess = failedLoggers;
            scheduleNextAttempt();
        } else {
            // All successful or max retries reached
            // Check if new loggers were added to the queue while we were processing
            if (!loggerQueue.isEmpty()) {
                // Schedule a new batch to process the new loggers
                scheduleBatch();
            } else {
                // No new loggers, reset the batch running flag
                isBatchRunning = false;
            }
        }
    }
    
    /**
     * Finish method - nothing to do here
     */
    global void finish(Database.BatchableContext bc) {
        // Nothing to do
    }
    
    /**
     * Schedules the next attempt with exponential backoff
     */
    private void scheduleNextAttempt() {
        // Calculate delay with exponential backoff: baseDelay * 2^retryCount
        Integer delayMinutes = baseDelayMinutes * (Integer)Math.pow(2, retryCount);
        
        // Create a new batch with incremented retry count and the failed loggers
        TritonDelayedPublishBatch nextBatch = new TritonDelayedPublishBatch(
            this.retryCount + 1, 
            this.loggersToProcess
        );
        
        // Schedule the batch to run after the calculated delay
        Datetime scheduledTime = Datetime.now().addMinutes(delayMinutes);
        String jobName = 'TritonDelayedPublish-' + Datetime.now().getTime();
        
        currentBatchId = System.scheduleBatch(nextBatch, jobName, delayMinutes);
    }
    
    /**
     * For testing - get the current size of the logger queue
     */
    @TestVisible
    private static Integer getQueueSize() {
        return loggerQueue.size();
    }
    
    /**
     * For testing - clear the queue and reset the batch running flag
     */
    @TestVisible
    private static void resetQueue() {
        loggerQueue.clear();
        isBatchRunning = false;
        currentBatchId = null;
    }
    
    /**
     * For testing - check if a batch is currently running
     */
    @TestVisible
    private static Boolean isRunning() {
        return isBatchRunning;
    }
} 