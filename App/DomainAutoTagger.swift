import Foundation

struct DomainAutoTagger: Sendable {

    // MARK: - Keyword → Domain Mapping

    private let keywordMap: [(keywords: [String], tag: DomainTag)] = [
        (
            ["transformers", "nltk", "spacy", "huggingface", "tokenizer", "bert", "gpt", "llm",
             "language-model", "text-classification", "sentiment", "ner", "seq2seq",
             "tokenization", "embedding", "langgraph", "langchain", "llamaindex", "llama-index",
             "vector-store", "rag", "retrieval", "chat completion", "claude api", "openai api"],
            .nlp
        ),
        (
            ["opencv", "yolo", "detectron", "torchvision", "pillow", "cv2", "image-classification",
             "object-detection", "segmentation", "albumentations", "timm", "video generation",
             "video gen", "videogen", "veo", "sora", "imagen", "kling", "runway", "pika",
             "frame interpolation", "optical flow", "depth estimation"],
            .computerVision
        ),
        (
            ["gymnasium", "gym", "stable-baselines", "reinforcement", "rllib", "pettingzoo",
             "policy", "reward", "q-learning", "actor-critic", "ppo", "sac", "dqn",
             "multi-agent", "environment", "episode", "markov"],
            .reinforcementLearning
        ),
        (
            ["librosa", "torchaudio", "whisper", "speechbrain", "pyaudio", "soundfile",
             "speech recognition", "text-to-speech", "asr", "tts", "waveform", "mel-spectrogram",
             "audio processing", "music generation", "voice cloning"],
            .audio
        ),
        (
            ["diffusers", "langchain", "langgraph", "openai", "anthropic", "claude", "gemini",
             "ollama", "generative ai", "ai-powered", "ai powered", "ai assistant", "ai chat",
             "gan", "vae", "stable-diffusion", "controlnet", "lora", "fine-tun",
             "llm", "gpt-4", "gpt4", "mistral", "llama", "groq", "together ai",
             "mcp", "model context protocol", "ai agent", "agentic", "tool use",
             "prompt engineering", "prompt", "completion"],
            .generativeAI
        ),
        (
            ["pandas", "spark", "airflow", "dbt", "kafka", "dagster",
             "prefect", "luigi", "pyspark", "polars", "dask", "data pipeline",
             "etl", "elt", "data warehouse", "data lake", "snowflake", "bigquery",
             "data engineering", "batch processing", "stream processing"],
            .dataEngineering
        ),
        (
            ["ros", "gazebo", "robotics", "mujoco", "isaacgym", "urdf", "moveit", "slam",
             "robot", "drone", "autonomous", "servo", "actuator", "lidar"],
            .robotics
        ),
        (
            ["swiftui", "uikit", "flutter", "react-native", "reactnative", "android",
             "xcodeproj", "storyboard", "jetpack", "compose",
             "swift", "kotlin", "objective-c", "xcode", "ios", "macos", "watchos", "tvos",
             "expo", "tauri", "electron", "native app", "mobile app", "desktop app",
             "appkit", "swiftdata", "coredata", "musickit", "widgetkit"],
            .appDev
        ),
        (
            ["tokio", "actix", "kernel", "driver", "embedded", "firmware",
             "rtos", "bare-metal", "cortex", "rust", "cargo",
             "c++", "cmake", "makefile", "assembly", "memory safety",
             "systems programming", "low-level", "webassembly", "wasm"],
            .systems
        ),
        (
            ["react", "nextjs", "next.js", "vue", "angular", "express", "fastapi",
             "django", "flask", "svelte", "nuxt", "remix", "tailwind",
             "typescript", "javascript", "node.js", "nodejs", "vite", "webpack",
             "rest api", "graphql", "supabase", "firebase", "vercel", "netlify",
             "web app", "frontend", "backend", "full-stack", "fullstack",
             "html", "css", "api server", "http server"],
            .webDev
        )
    ]

    // MARK: - Extension → Domain Mapping

    private let mlModelExtensions: Set<String> = [".pt", ".pth", ".onnx", ".safetensors"]
    private let appDevExtensions: Set<String> = [".swift", ".xcodeproj", ".xib", ".storyboard"]
    private let systemsExtensions: Set<String> = [".rs", ".c", ".cpp", ".h"]
    private let audioExtensions: Set<String> = [".wav", ".mp3", ".flac", ".mid"]
    private let webDevExtensions: Set<String> = [".tsx", ".jsx", ".vue", ".svelte"]

    // MARK: - Public API

    func autoTag(repoPath: String) -> [DomainTag] {
        var tagSet: Set<DomainTag> = []

        // Signal 1: Repo name
        let repoName = URL(fileURLWithPath: repoPath).lastPathComponent.lowercased()
        tagSet.formUnion(tagsFromKeywords(in: repoName))

        // Signal 2: README content (lowercased — keywords match badge alt-text, labels, and prose)
        let readmeNames = ["README.md", "README.MD", "readme.md", "Readme.md"]
        for readmeName in readmeNames {
            if let raw = runGit(args: ["-C", repoPath, "show", "HEAD:\(readmeName)"]) {
                let content = String(raw.prefix(12000)).lowercased()
                tagSet.formUnion(tagsFromKeywords(in: content))
                break
            }
        }

        // Signal 3: File tree (extensions and filenames)
        if let treeOutput = runGit(args: ["-C", repoPath, "ls-tree", "-r", "--name-only", "HEAD"]) {
            let files = treeOutput
                .split(separator: "\n")
                .map { String($0) }
            tagSet.formUnion(tagsFromFileTree(files: files))
        }

        // Signal 4: Dependency files
        let dependencyFiles = [
            "requirements.txt",
            "pyproject.toml",
            "package.json",
            "Cargo.toml",
            "go.mod"
        ]
        for depFile in dependencyFiles {
            if let raw = runGit(args: ["-C", repoPath, "show", "HEAD:\(depFile)"]) {
                let content = raw.lowercased()
                tagSet.formUnion(tagsFromKeywords(in: content))
            }
        }

        return Array(tagSet)
    }

    // MARK: - Private Helpers

    private func tagsFromKeywords(in text: String) -> Set<DomainTag> {
        var result: Set<DomainTag> = []
        for entry in keywordMap {
            for keyword in entry.keywords {
                if text.contains(keyword) {
                    result.insert(entry.tag)
                    break
                }
            }
        }
        return result
    }

    private func tagsFromFileTree(files: [String]) -> Set<DomainTag> {
        var result: Set<DomainTag> = []

        // Count occurrences of each relevant extension
        var extensionCounts: [String: Int] = [:]
        for file in files {
            let ext = "." + (file.split(separator: ".").last.map(String.init) ?? "")
            extensionCounts[ext, default: 0] += 1

            // Also check filenames against keyword map
            let filename = URL(fileURLWithPath: file).lastPathComponent.lowercased()
            result.formUnion(tagsFromKeywords(in: filename))
        }

        // ML model extensions → .nlp and .computerVision
        let mlModelCount = mlModelExtensions.reduce(0) { $0 + (extensionCounts[$1] ?? 0) }
        if mlModelCount >= 2 {
            result.insert(.nlp)
            result.insert(.computerVision)
        }

        // App dev extensions — even 1 .swift file is a strong signal
        let appDevCount = appDevExtensions.reduce(0) { $0 + (extensionCounts[$1] ?? 0) }
        if appDevCount >= 1 {
            result.insert(.appDev)
        }

        // Systems extensions
        let systemsCount = systemsExtensions.reduce(0) { $0 + (extensionCounts[$1] ?? 0) }
        if systemsCount >= 2 {
            result.insert(.systems)
        }

        // Audio extensions
        let audioCount = audioExtensions.reduce(0) { $0 + (extensionCounts[$1] ?? 0) }
        if audioCount >= 2 {
            result.insert(.audio)
        }

        // Web dev extensions
        let webDevCount = webDevExtensions.reduce(0) { $0 + (extensionCounts[$1] ?? 0) }
        if webDevCount >= 2 {
            result.insert(.webDev)
        }

        return result
    }

    private func runGit(args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.environment = ["HOME": NSHomeDirectory(), "GIT_TERMINAL_PROMPT": "0"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Read stdout BEFORE waitUntilExit to prevent pipe-buffer deadlock.
        // (Large git ls-tree output can exceed the 64KB pipe buffer, blocking the
        // subprocess write — which then blocks waitUntilExit — forever.)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
