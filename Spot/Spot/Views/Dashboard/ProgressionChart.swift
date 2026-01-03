//
//  ProgressionChart.swift
//  Spot
//
//  Line chart showing weight/volume progression over time.
//  Includes exercise filter and metric toggle.
//

import SwiftUI
import Charts

struct ProgressionChart: View {
    let exercises: [Exercise]
    let sessions: [WorkoutSession]
    
    @State private var selectedExercise: Exercise?
    @State private var metricType: MetricType = .weight
    @State private var showExercisePicker = false
    
    enum MetricType: String, CaseIterable {
        case weight = "Weight"
        case volume = "Volume"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.sm) {
            // Header
            HStack {
                Text("Progression")
                    .font(SpotTheme.Typography.headline)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Spacer()
                
                // Metric toggle
                Picker("Metric", selection: $metricType) {
                    ForEach(MetricType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            
            // Exercise selector
            Button {
                showExercisePicker = true
            } label: {
                HStack {
                    Text(selectedExercise?.name ?? "Select Exercise")
                        .font(SpotTheme.Typography.subheadline)
                        .foregroundStyle(selectedExercise != nil ? SpotTheme.textPrimary : SpotTheme.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SpotTheme.textSecondary)
                }
                .padding(.horizontal, SpotTheme.Spacing.sm)
                .padding(.vertical, SpotTheme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: SpotTheme.Radius.small)
                        .fill(SpotTheme.textPrimary.opacity(0.05))
                )
            }
            
            // Chart
            if let exercise = selectedExercise {
                let dataPoints = progressionData(for: exercise)
                
                if dataPoints.isEmpty {
                    emptyChartState
                } else {
                    chartView(dataPoints: dataPoints)
                }
            } else {
                emptySelectionState
            }
            
            // PR indicator
            if let exercise = selectedExercise {
                prIndicator(for: exercise)
            }
        }
        .padding(SpotTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SpotTheme.Radius.medium, style: .continuous)
                .fill(SpotTheme.textPrimary.opacity(0.03))
        )
        .sheet(isPresented: $showExercisePicker) {
            exercisePickerSheet
        }
        .onAppear {
            // Auto-select first exercise with history
            if selectedExercise == nil {
                selectedExercise = exercises.first { !$0.history.isEmpty }
            }
        }
    }
    
    // MARK: - Chart
    
    @ViewBuilder
    private func chartView(dataPoints: [ProgressDataPoint]) -> some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value(metricType.rawValue, point.value)
            )
            .foregroundStyle(SpotTheme.sage)
            .interpolationMethod(.catmullRom)
            
            PointMark(
                x: .value("Date", point.date),
                y: .value(metricType.rawValue, point.value)
            )
            .foregroundStyle(point.isPR ? SpotTheme.clay : SpotTheme.sage)
            .symbolSize(point.isPR ? 80 : 40)
            
            if point.isPR {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(metricType.rawValue, point.value)
                )
                .foregroundStyle(SpotTheme.clay.opacity(0.3))
                .symbolSize(120)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(SpotTheme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .foregroundStyle(SpotTheme.textSecondary)
                AxisGridLine()
                    .foregroundStyle(SpotTheme.textSecondary.opacity(0.2))
            }
        }
        .chartYScale(domain: yAxisDomain(for: dataPoints))
        .frame(height: 200)
    }
    
    private var emptyChartState: some View {
        VStack(spacing: SpotTheme.Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.5))
            
            Text("No data yet")
                .font(SpotTheme.Typography.subheadline)
                .foregroundStyle(SpotTheme.textSecondary)
            
            Text("Log some sets to see your progress!")
                .font(SpotTheme.Typography.caption)
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.7))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private var emptySelectionState: some View {
        VStack(spacing: SpotTheme.Spacing.sm) {
            Image(systemName: "hand.tap")
                .font(.system(size: 32))
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.5))
            
            Text("Select an exercise")
                .font(SpotTheme.Typography.subheadline)
                .foregroundStyle(SpotTheme.textSecondary)
            
            Text("Tap above to choose an exercise and view your progression")
                .font(SpotTheme.Typography.caption)
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - PR Indicator
    
    @ViewBuilder
    private func prIndicator(for exercise: Exercise) -> some View {
        if let maxWeight = exercise.allTimeMaxWeight, maxWeight > 0 {
            HStack(spacing: SpotTheme.Spacing.xs) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(SpotTheme.sage)
                
                Text("PR: \(Int(maxWeight)) lbs")
                    .font(SpotTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                if let maxVolume = exercise.allTimeMaxVolume, maxVolume > 0 {
                    Text("• Volume PR: \(Int(maxVolume)) lbs")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                }
            }
            .padding(.top, SpotTheme.Spacing.xs)
        }
    }
    
    // MARK: - Exercise Picker
    
    private var exercisePickerSheet: some View {
        NavigationView {
            List {
                ForEach(exercisesWithHistory) { exercise in
                    Button {
                        selectedExercise = exercise
                        showExercisePicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(SpotTheme.Typography.body)
                                    .foregroundStyle(SpotTheme.textPrimary)
                                
                                Text("\(exercise.muscleGroup) • \(exercise.history.count) session\(exercise.history.count == 1 ? "" : "s")")
                                    .font(SpotTheme.Typography.caption)
                                    .foregroundStyle(SpotTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            if exercise.id == selectedExercise?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(SpotTheme.sage)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showExercisePicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Data
    
    private func yAxisDomain(for dataPoints: [ProgressDataPoint]) -> ClosedRange<Double> {
        let values = dataPoints.map(\.value)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        
        // Ensure we always have a visible range
        if minVal == maxVal {
            return 0...(max(maxVal, 10) + 10)
        }
        let padding = (maxVal - minVal) * 0.1
        return max(0, minVal - padding)...(maxVal + padding)
    }
    
    private var exercisesWithHistory: [Exercise] {
        exercises.filter { !$0.history.isEmpty }
            .sorted { $0.name < $1.name }
    }
    
    private func progressionData(for exercise: Exercise) -> [ProgressDataPoint] {
        // Get all workout exercises for this exercise, sorted by date
        let workoutExercises = exercise.history
            .sorted { ($0.session?.startTime ?? .distantPast) < ($1.session?.startTime ?? .distantPast) }
        
        var dataPoints: [ProgressDataPoint] = []
        var runningMaxWeight: Double = 0
        
        for workoutExercise in workoutExercises {
            guard let session = workoutExercise.session else { continue }
            
            let sets = workoutExercise.orderedSets
            if sets.isEmpty { continue }
            
            let value: Double
            let isPR: Bool
            
            switch metricType {
            case .weight:
                let maxWeight = sets.map(\.weight).max() ?? 0
                value = maxWeight
                isPR = maxWeight > runningMaxWeight
                if isPR { runningMaxWeight = maxWeight }
            case .volume:
                let totalVolume = sets.reduce(0.0) { $0 + $1.volume }
                value = totalVolume
                isPR = sets.contains { $0.isPR }
            }
            
            dataPoints.append(ProgressDataPoint(
                date: session.startTime,
                value: value,
                isPR: isPR
            ))
        }
        
        return dataPoints
    }
}

// MARK: - Data Point

struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isPR: Bool
}

// MARK: - Preview

#Preview("Progression Chart") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        ProgressionChart(exercises: [], sessions: [])
            .padding()
    }
}

