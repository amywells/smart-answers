module SmartAnswer
  class CalculateYourHolidayEntitlementFlow < Flow
    def define
      start_page_content_id "deedf6f8-389b-4b34-a5b1-faa9ef909a70"
      flow_content_id "ebc97e28-85be-4f9f-8637-b2d43be9f0a6"
      name "calculate-your-holiday-entitlement"
      status :published
      satisfies_need "a22c3cfa-0590-4a00-9846-f67df3df0071"

      # Q1
      multiple_choice :basis_of_calculation? do
        option "days-worked-per-week"
        option "hours-worked-per-week"
        option "irregular-hours"
        option "annualised-hours"
        option "compressed-hours"
        option "shift-worker"
        save_input_as :calculation_basis

        calculate :leaving_date
        calculate :leave_year_start_date
        calculate :start_date

        next_node do |response|
          case response
          when "days-worked-per-week", "hours-worked-per-week", "compressed-hours", "irregular-hours", "annualised-hours"
            question :calculation_period?
          when "shift-worker"
            question :shift_worker_basis?
          end
        end
      end

      # Q2, Q35
      multiple_choice :calculation_period? do
        option "full-year"
        option "starting"
        option "leaving"
        option "starting-and-leaving"
        save_input_as :holiday_period

        next_node do |response|
          case response
          when "starting", "starting-and-leaving"
            question :what_is_your_starting_date?
          when "leaving"
            question :what_is_your_leaving_date?
          when "full-year"
            if calculation_basis == "irregular-hours" || calculation_basis == "annualised-hours"
              outcome :irregular_and_annualised_done
            elsif calculation_basis == "days-worked-per-week"
              question :how_many_days_per_week?
            else
              question :how_many_hours_per_week?
            end
          end
        end
      end

      # Q3 - Q7 - Q8
      value_question :how_many_days_per_week?, parse: Float do
        calculate :working_days_per_week do |response|
          working_days_per_week = response
          raise InvalidResponse if working_days_per_week <= 0 || working_days_per_week > 7

          working_days_per_week
        end
        next_node do
          outcome :days_per_week_done
        end
      end

      # Q4 - Q12 - Q20 - Q29 - Q36
      date_question :what_is_your_starting_date? do
        from { Date.civil(1.year.ago.year, 1, 1) }
        to { Date.civil(1.year.since(Time.zone.today).year, 12, 31) }
        save_input_as :start_date

        next_node do
          if holiday_period == "starting-and-leaving"
            question :what_is_your_leaving_date?
          else
            question :when_does_your_leave_year_start?
          end
        end
      end

      # Q5 - Q13 - Q21 - Q29 - Q30 - Q37
      date_question :what_is_your_leaving_date? do
        from { Date.civil(1.year.ago.year, 1, 1) }
        to { Date.civil(1.year.since(Time.zone.today).year, 12, 31) }

        calculate :leaving_date do |response|
          leaving_date = response
          if holiday_period == "starting-and-leaving"
            raise InvalidResponse, :error_end_date_before_start_date if leaving_date <= start_date

            raise InvalidResponse, :error_end_date_outside_year_range unless YearRange.new(begins_on: start_date).include?(leaving_date)
          end

          leaving_date
        end

        next_node do
          if holiday_period == "starting-and-leaving"
            case calculation_basis
            when "days-worked-per-week"
              question :how_many_days_per_week?
            when "hours-worked-per-week", "compressed-hours"
              question :how_many_hours_per_week?
            when "shift-worker"
              question :shift_worker_hours_per_shift?
            when "irregular-hours", "annualised-hours"
              outcome :irregular_and_annualised_done
            end
          else
            question :when_does_your_leave_year_start?
          end
        end
      end

      # Q6 - Q14 - Q22 - Q31 - Q38
      date_question :when_does_your_leave_year_start? do
        from { Date.civil(1.year.ago.year, 1, 1) }
        to { Date.civil(1.year.since(Time.zone.today).year, 12, 31) }

        calculate :leave_year_start_date do |response|
          leave_year_start_date = response
          if leaving_date.present?
            raise InvalidResponse, :error_end_date_before_start_date if leaving_date <= leave_year_start_date

            raise InvalidResponse, :error_end_date_outside_leave_year_range unless YearRange.new(begins_on: leave_year_start_date).include?(leaving_date)
          end
          if start_date
            raise InvalidResponse, :error_start_date_before_start_leave_year_date if start_date <= leave_year_start_date
            raise InvalidResponse, :error_start_date_outside_leave_year_range unless YearRange.new(begins_on: leave_year_start_date).include?(start_date)
          end
          leave_year_start_date
        end

        next_node do
          case calculation_basis
          when "days-worked-per-week"
            question :how_many_days_per_week?
          when "hours-worked-per-week", "compressed-hours"
            question :how_many_hours_per_week?
          when "irregular-hours", "annualised-hours"
            outcome :irregular_and_annualised_done
          when "shift-worker"
            question :shift_worker_hours_per_shift?
          end
        end
      end

      # Q10 - Q15 - Q18
      value_question :how_many_hours_per_week?, parse: Float do
        calculate :hours_per_week do |response|
          hours_per_week = response
          raise InvalidResponse, :error_over_168_hours_worked if hours_per_week > 168

          raise InvalidResponse, :error_no_hours_worked if hours_per_week <= 0

          hours_per_week
        end

        next_node do
          question :how_many_days_per_week_for_hours?
        end
      end

      # Q11 - Q16 - Q19
      value_question :how_many_days_per_week_for_hours?, parse: Float do
        calculate :working_days_per_week do |response|
          working_days_per_week = response
          raise InvalidResponse, :error_over_7_days_per_week if working_days_per_week <= 0 || working_days_per_week > 7

          if hours_per_week
            raise InvalidResponse, :error_over_24_hours_per_day if (hours_per_week / working_days_per_week) > 24
          end
          working_days_per_week
        end

        next_node do
          if calculation_basis == "compressed-hours"
            outcome :compressed_hours_done
          else
            outcome :hours_per_week_done
          end
        end
      end

      multiple_choice :shift_worker_basis? do
        option "full-year"
        option "starting"
        option "leaving"
        option "starting-and-leaving"
        save_input_as :holiday_period

        next_node do |response|
          case response
          when "full-year"
            question :shift_worker_hours_per_shift?
          when "starting", "starting-and-leaving"
            question :what_is_your_starting_date?
          when "leaving"
            question :what_is_your_leaving_date?
          end
        end
      end

      # Q26 - Q32
      value_question :shift_worker_hours_per_shift?, parse: Float do
        calculate :hours_per_shift do |response|
          hours_per_shift = response
          raise InvalidResponse, :error_no_hours_worked if hours_per_shift <= 0
          raise InvalidResponse, :error_over_24_hours_worked if hours_per_shift > 24

          hours_per_shift
        end
        next_node do
          question :shift_worker_shifts_per_shift_pattern?
        end
      end

      # Q27 - Q33
      value_question :shift_worker_shifts_per_shift_pattern?, parse: Integer do
        calculate :shifts_per_shift_pattern do |response|
          shifts = response
          raise InvalidResponse if shifts <= 0

          shifts
        end
        next_node do
          question :shift_worker_days_per_shift_pattern?
        end
      end

      # Q28 - Q34
      value_question :shift_worker_days_per_shift_pattern?, parse: Float do
        calculate :days_per_shift_pattern do |response|
          days = response
          raise InvalidResponse if days < shifts_per_shift_pattern

          days
        end

        next_node do
          outcome :shift_worker_done
        end
      end

      outcome :shift_worker_done do
        precalculate :calculator do
          Calculators::HolidayEntitlement.new(
            start_date: start_date,
            leaving_date: leaving_date,
            leave_year_start_date: leave_year_start_date,
            shifts_per_shift_pattern: shifts_per_shift_pattern,
            days_per_shift_pattern: days_per_shift_pattern,
          )
        end
        precalculate :holiday_entitlement_shifts do
          calculator.shift_entitlement
        end
        precalculate :shifts_per_week do
          calculator.shifts_per_week
        end
      end

      outcome :days_per_week_done do
        precalculate :calculator do
          Calculators::HolidayEntitlement.new(
            working_days_per_week: working_days_per_week,
            start_date: start_date,
            leaving_date: leaving_date,
            leave_year_start_date: leave_year_start_date,
          )
        end
        precalculate :holiday_entitlement_days do
          calculator.formatted_full_time_part_time_days
        end
      end

      outcome :hours_per_week_done do
        precalculate :calculator do
          Calculators::HolidayEntitlement.new(
            hours_per_week: hours_per_week,
            working_days_per_week: working_days_per_week,
            start_date: start_date,
            leaving_date: leaving_date,
            leave_year_start_date: leave_year_start_date,
          )
        end
        precalculate :holiday_entitlement_hours do
          calculator.formatted_full_time_part_time_compressed_hours
        end
      end

      outcome :compressed_hours_done do
        precalculate :calculator do
          Calculators::HolidayEntitlement.new(
            hours_per_week: hours_per_week,
            working_days_per_week: working_days_per_week,
            start_date: start_date,
            leaving_date: leaving_date,
            leave_year_start_date: leave_year_start_date,
          )
        end
        precalculate :holiday_entitlement_hours do
          calculator.full_time_part_time_hours_and_minutes.first
        end
        precalculate :holiday_entitlement_minutes do
          calculator.full_time_part_time_hours_and_minutes.last
        end
        precalculate :hours_daily do
          calculator.compressed_hours_daily_average.first
        end
        precalculate :minutes_daily do
          calculator.compressed_hours_daily_average.last
        end
      end

      outcome :irregular_and_annualised_done do
        precalculate :calculator do
          Calculators::HolidayEntitlement.new(
            start_date: start_date,
            leave_year_start_date: leave_year_start_date,
            leaving_date: leaving_date,
          )
        end
        precalculate :holiday_entitlement do
          calculator.formatted_full_time_part_time_weeks
        end
      end
    end
  end
end
