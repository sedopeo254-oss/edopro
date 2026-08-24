using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;

namespace WindBot.Game.AI
{
    // Lightweight reader for Ai Duel's exported memory.
    // It reads AiDuel.ActionMemory.tsv so it does not require a JSON package.
    public sealed class AiDuelKnowledgeReader
    {
        public sealed class ActionStat
        {
            public string Phase;
            public string Action;
            public int CardId;
            public string CardName;
            public int Samples;
            public int Wins;
            public int Losses;
            public double WinRate
            {
                get
                {
                    int decided = Wins + Losses;
                    return decided <= 0 ? 0.5 : (double)Wins / decided;
                }
            }
        }

        readonly Dictionary<string, ActionStat> Stats = new Dictionary<string, ActionStat>(StringComparer.OrdinalIgnoreCase);
        public string SourcePath { get; private set; }
        public int Count { get { return Stats.Count; } }

        static string Key(string phase, string action, int cardId)
        {
            return (phase ?? "") + "|" + (action ?? "") + "|" + cardId.ToString(CultureInfo.InvariantCulture);
        }

        public bool Load(string path)
        {
            Stats.Clear();
            SourcePath = path;
            if (string.IsNullOrEmpty(path) || !File.Exists(path)) return false;
            string[] lines = File.ReadAllLines(path);
            for (int i = 1; i < lines.Length; i++)
            {
                string line = lines[i];
                if (string.IsNullOrWhiteSpace(line)) continue;
                string[] p = line.Split('\t');
                if (p.Length < 7) continue;
                int cardId, samples, wins, losses;
                int.TryParse(p[2], NumberStyles.Integer, CultureInfo.InvariantCulture, out cardId);
                int.TryParse(p[4], NumberStyles.Integer, CultureInfo.InvariantCulture, out samples);
                int.TryParse(p[5], NumberStyles.Integer, CultureInfo.InvariantCulture, out wins);
                int.TryParse(p[6], NumberStyles.Integer, CultureInfo.InvariantCulture, out losses);
                ActionStat s = new ActionStat
                {
                    Phase = p[0], Action = p[1], CardId = cardId, CardName = p[3],
                    Samples = samples, Wins = wins, Losses = losses
                };
                Stats[Key(s.Phase, s.Action, s.CardId)] = s;
            }
            return true;
        }

        public ActionStat Get(string phase, string action, int cardId)
        {
            ActionStat s;
            Stats.TryGetValue(Key(phase, action, cardId), out s);
            return s;
        }

        // Score is deliberately a bias, not an absolute command.
        // WindBot should combine it with legal-move checks and deck-specific Executors.
        public double Score(string phase, string action, int cardId)
        {
            ActionStat s = Get(phase, action, cardId);
            if (s == null || s.Samples <= 0) return 0.0;
            double confidence = Math.Min(1.0, Math.Log10(1.0 + s.Samples) / 2.0);
            double centered = (s.WinRate - 0.5) * 2.0;
            return centered * confidence;
        }

        public IEnumerable<ActionStat> All()
        {
            return Stats.Values;
        }
    }
}
