

function [violation] = checkProbabilityConstraint(JEP, TR_exceed)
    % Verify inclusion-exclusion constraint: JEP <= TR
    violation = JEP > (TR_exceed + 1e-10);  % Allow small numerical tolerance
end
