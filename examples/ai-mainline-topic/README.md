# Offline AI topic-scoring example

This example shows the first decision in the workflow: turning a small candidate pool into one topic worth producing. It uses five fixed candidates and a visible scoring rubric, so the same command produces the same ranking on every machine. It does not browse the web or read a personal knowledge base.

From the repository root, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-ai-daily-topic-chain.ps1 `
  -InputPath .\examples\ai-mainline-topic\candidates.example.json `
  -RubricPath .\examples\ai-mainline-topic\rubric.example.json `
  -OutputRoot .\output\ai-mainline-topic
```

The command writes `topic-ranking.json` and `topic-decision.md`. The ranking includes the weighted score, an explanation for each score, the selected topic, and a rejection reason for every other candidate.

The fixture is deliberately generic. Replace the candidates with your own evidence and tune the rubric to your account. Keep the field names and the score range from 1 to 5 unless you also update the rubric. Live collection is a separate, explicit step; this example never turns it on.
