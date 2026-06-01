System Role: You are an expert Software Architect and Lead Mobile Developer.

Project Context: I am developing an AI-powered fitness coaching mobile application. The technical stack includes Flutter (frontend/UI), Google ML Kit/MediaPipe (computer vision), Gemini LLM (reasoning/analytics), and Supabase (backend/database).

Below are the defined Functional Requirements (FRs) broken down by Main Module. Please ingest this context to understand the system's scope.

Module 1: User & Authentication
FR-1.1: Users shall be able to register and log in to an account using an email and password via the Flutter mobile app. (Priority: Must-Have)

FR-1.2: Users shall be able to input and update their personal biometric profile (e.g., height, weight, fitness goals) to calibrate the AI reasoning engine. (Priority: Must-Have)

Module 2: Motion Tracking & Form Correction
FR-2.1: The system shall capture a live camera feed and extract 33 3D skeletal landmarks of a single user using the Google ML Kit/MediaPipe framework. (Priority: Must-Have)

FR-2.2: The system shall calculate joint angles (knees, hips, elbows) to continuously evaluate the biomechanical form of squats, push-ups, and bicep curls. (Priority: Must-Have)

FR-2.3: The system shall trigger low-latency Text-to-Speech (TTS) voice-overs to provide immediate corrective advice when posture deviates from the standard. (Priority: Must-Have)

FR-2.4: The system shall increment a dynamic repetition counter and update an Interactive Endurance Bar based on calculated Time Under Tension (TUT) and Range of Motion (ROM). (Priority: Must-Have)

Module 3: Personalized Workout Plans
FR-3.1: The system shall securely transmit the user's historical performance data (form accuracy, fatigue levels) to the Gemini LLM API for analysis. (Priority: Must-Have)

FR-3.2: The system shall utilize Gemini to generate and display dynamic, personalized weekly workout blocks, including the assignment of training intensities and rest days. (Priority: Must-Have)

Module 4: Progress Tracking & Analytics
FR-4.1: The system shall synchronize and save all completed session data, including repetition counts and form accuracy scores, to the Supabase cloud database. (Priority: Must-Have)

FR-4.2: The mobile app shall display a performance dashboard summarizing daily and weekly activity, including total repetitions and estimated calories burned. (Priority: Should-Have)

Module 5: Video Tutorials & Community
FR-5.1: The system shall simultaneously display a YouTube tutorial video and the user's live skeletal camera feed within a unified "Mirror-Coach" interface. (Priority: Should-Have)

FR-5.2: Users shall be able to publish text-based session summaries (reps, calories, endurance scores) to a centralized community forum hosted on Supabase. (Priority: Could-Have)