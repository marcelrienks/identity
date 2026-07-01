#!/bin/bash

# AWS CloudFormation API wrapper functions (T006)
# Provides: Stack management, template operations, event polling, output parsing

# Check if CloudFormation stack exists
cfn_stack_exists() {
    local stack_name="$1"
    local region="${2:-${AWS_REGION:-us-east-1}}"
    local aws_profile="${3:-${AWS_PROFILE:-default}}"

    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --profile "$aws_profile" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null | grep -q . && return 0 || return 1
}

# Describe CloudFormation stack (get all details)
cfn_describe_stack() {
    local stack_name="$1"
    local region="${2:-${AWS_REGION:-us-east-1}}"
    local aws_profile="${3:-${AWS_PROFILE:-default}}"

    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --profile "$aws_profile" \
        --output json 2>/dev/null
}

# Get CloudFormation stack status
cfn_get_stack_status() {
    local stack_name="$1"
    local region="${2:-${AWS_REGION:-us-east-1}}"
    local aws_profile="${3:-${AWS_PROFILE:-default}}"

    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --profile "$aws_profile" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null
}

# Convert KEY=VALUE parameters to AWS CloudFormation format
_format_cfn_parameters() {
    local -n params_ref=$1
    local -a formatted=()

    for param in "${params_ref[@]}"; do
        local key="${param%%=*}"
        local value="${param#*=}"
        formatted+=("ParameterKey=$key,ParameterValue=$value")
    done

    echo "${formatted[@]}"
}

# Create CloudFormation stack
cfn_create_stack() {
    local stack_name="$1"
    local template_file="$2"
    local parameters_array_ref="$3"  # Name of array variable with KEY=VALUE parameters
    local region="${4:-${AWS_REGION:-us-east-1}}"
    local aws_profile="${5:-${AWS_PROFILE:-default}}"

    debug "Creating CloudFormation stack: $stack_name"
    debug "Template: $template_file"

    if [[ ! -f "$template_file" ]]; then
        error "Template file not found: $template_file"
        return $EXIT_ERROR
    fi

    # Build parameters argument if provided
    local -a param_args=()
    if [[ -n "$parameters_array_ref" ]]; then
        # Get the array by name and format for AWS CLI
        local -n params_arr="$parameters_array_ref"
        local formatted_params=$(_format_cfn_parameters params_arr)
        if [[ -n "$formatted_params" ]]; then
            param_args+=(--parameters $formatted_params)
        fi
    fi

    # Create stack
    if ! aws cloudformation create-stack \
        --stack-name "$stack_name" \
        --template-body "file://$template_file" \
        --region "$region" \
        "${param_args[@]}" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --profile "$aws_profile" \
        --output text 2>&1; then

        error "Failed to create CloudFormation stack: $stack_name"
        return $EXIT_AWS_ERROR
    fi

    debug "Stack creation initiated: $stack_name"
    return $EXIT_SUCCESS
}

# Update CloudFormation stack
cfn_update_stack() {
    local stack_name="$1"
    local template_file="$2"
    local parameters_array_ref="$3"  # Name of array variable with KEY=VALUE parameters
    local region="${4:-${AWS_REGION:-us-east-1}}"
    local aws_profile="${5:-${AWS_PROFILE:-default}}"

    debug "Updating CloudFormation stack: $stack_name"

    if [[ ! -f "$template_file" ]]; then
        error "Template file not found: $template_file"
        return $EXIT_ERROR
    fi

    # Build parameters argument
    local -a param_args=()
    if [[ -n "$parameters_array_ref" ]]; then
        # Get the array by name and format for AWS CLI
        local -n params_arr="$parameters_array_ref"
        local formatted_params=$(_format_cfn_parameters params_arr)
        if [[ -n "$formatted_params" ]]; then
            param_args+=(--parameters $formatted_params)
        fi
    fi

    # Update stack
    local update_result
    update_result=$(aws cloudformation update-stack \
        --stack-name "$stack_name" \
        --template-body "file://$template_file" \
        --region "$region" \
        "${param_args[@]}" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --profile "$aws_profile" \
        --output text 2>&1) || {

        # Check if error is "No updates are to be performed"
        if echo "$update_result" | grep -q "No updates are to be performed"; then
            debug "No updates needed for stack: $stack_name"
            return $EXIT_SUCCESS
        else
            error "Failed to update CloudFormation stack: $stack_name"
            error "$update_result"
            return $EXIT_AWS_ERROR
        fi
    }

    debug "Stack update initiated: $stack_name"
    return $EXIT_SUCCESS
}

# Get stack output values (e.g., S3 bucket name, CloudFront domain)
cfn_get_stack_outputs() {
    local stack_name="$1"
    local region="${2:-${AWS_REGION:-us-east-1}}"
    local aws_profile="${3:-${AWS_PROFILE:-default}}"

    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --profile "$aws_profile" \
        --query 'Stacks[0].Outputs' \
        --output json 2>/dev/null
}

# Get specific stack output value by key
cfn_get_stack_output() {
    local stack_name="$1"
    local output_key="$2"
    local region="${3:-${AWS_REGION:-us-east-1}}"
    local aws_profile="${4:-${AWS_PROFILE:-default}}"

    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --profile "$aws_profile" \
        --query "Stacks[0].Outputs[?OutputKey=='$output_key'].OutputValue" \
        --output text 2>/dev/null
}

# Poll stack creation/update progress
cfn_poll_stack_operation() {
    local stack_name="$1"
    local operation="$2"  # CREATE or UPDATE
    local max_wait_seconds="${3:-600}"  # Default: 10 minutes
    local aws_profile="${4:-${AWS_PROFILE:-default}}"
    
    local elapsed=0
    local poll_interval=10
    
    debug "Polling CloudFormation stack operation: $operation on $stack_name"
    
    while [[ $elapsed -lt $max_wait_seconds ]]; do
        local status
        status=$(cfn_get_stack_status "$stack_name" "$aws_profile")
        
        case "$status" in
            "${operation}_IN_PROGRESS")
                info "Stack ${operation} in progress... ($elapsed seconds)"
                sleep $poll_interval
                ((elapsed += poll_interval))
                ;;
            
            "${operation}_COMPLETE")
                success "Stack ${operation} completed successfully"
                return $EXIT_SUCCESS
                ;;
            
            "${operation}_ROLLBACK_IN_PROGRESS")
                error "Stack ${operation} rolled back (in progress)"
                cfn_describe_stack_events "$stack_name" "$aws_profile" | tail -5
                sleep $poll_interval
                ((elapsed += poll_interval))
                ;;
            
            "${operation}_ROLLBACK_COMPLETE")
                error "Stack ${operation} rolled back (completed)"
                cfn_describe_stack_events "$stack_name" "$aws_profile" | tail -5
                return $EXIT_AWS_ERROR
                ;;
            
            "${operation}_FAILED")
                error "Stack ${operation} failed"
                cfn_describe_stack_events "$stack_name" "$aws_profile" | tail -5
                return $EXIT_AWS_ERROR
                ;;
            
            "DELETE_IN_PROGRESS")
                error "Stack is being deleted"
                return $EXIT_AWS_ERROR
                ;;
            
            "DELETE_COMPLETE")
                error "Stack has been deleted"
                return $EXIT_AWS_ERROR
                ;;
            
            *)
                error "Unknown stack status: $status"
                return $EXIT_AWS_ERROR
                ;;
        esac
    done
    
    error "Stack ${operation} timed out after ${max_wait_seconds}s"
    return $EXIT_TIMEOUT
}

# Get stack events (for debugging)
cfn_describe_stack_events() {
    local stack_name="$1"
    local region="${2:-${AWS_REGION:-us-east-1}}"
    local aws_profile="${3:-${AWS_PROFILE:-default}}"

    aws cloudformation describe-stack-events \
        --stack-name "$stack_name" \
        --region "$region" \
        --profile "$aws_profile" \
        --query 'StackEvents[*].[Timestamp,ResourceStatus,LogicalResourceId,ResourceStatusReason]' \
        --output table 2>/dev/null || true
}

# Delete CloudFormation stack
cfn_delete_stack() {
    local stack_name="$1"
    local region="${2:-${AWS_REGION:-us-east-1}}"
    local aws_profile="${3:-${AWS_PROFILE:-default}}"

    debug "Deleting CloudFormation stack: $stack_name"

    aws cloudformation delete-stack \
        --stack-name "$stack_name" \
        --region "$region" \
        --profile "$aws_profile" \
        --output text 2>/dev/null

    debug "Stack deletion initiated: $stack_name"
    return $EXIT_SUCCESS
}

export -f cfn_stack_exists cfn_describe_stack cfn_get_stack_status
export -f cfn_create_stack cfn_update_stack cfn_get_stack_outputs cfn_get_stack_output
export -f cfn_poll_stack_operation cfn_describe_stack_events cfn_delete_stack
