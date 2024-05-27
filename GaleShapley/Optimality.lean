import GaleShapley.Matching
import GaleShapley.Basic
import GaleShapley.Lemmas

/-!

  # Proof of proposer optimality theorem

  We give the proof of the proposer optimality theorem `proposerOptimal`.
  The proof is standard and can be found in Gale and Shapley's original
  paper as well as many other sources.

  The theorem states that the Gale-Shapley algorithm gives a matching
  which is at least as preferable for every m in M compared to any other
  stable matching.

  The main step is `neverRejectedByPossibleMatch'`, which states that if
  there is some stable matching sending m to w, then w never rejects m in
  the Gale-Shapley algorithm.
-/
namespace GaleShapley

open Classical GaleShapley.Iterate
noncomputable section

variable {M W: Type} [Fintype M] [Fintype W] [Nonempty M] [Nonempty W]
  (mPref: Pref M W)
  (wPref: Pref W M)

-- (m, w) are a possible match if there is some stable matching sending m to w.
def possibleMatch (m: M) (w: W) := ∃ matching, matching m = some w ∧ isStableMatching mPref wPref matching

-- this is the hard step
lemma neverRejectedByPossibleMatch' (state: GaleShapleyState M W) (m: M) (w: W):
    state ∈ galeShapleyList mPref wPref → possibleMatch mPref wPref m w →
      ∀ s ∈ galeShapleyList mPref wPref, ∀ (nd: notDone s), state ∈ galeShapleyIterate s →
        ¬ rejectedAtState nd m w := by
  intro state_in_gsList
  have := stateStrongInduction galeShapleyTerminator (initialState mPref wPref)
  simp at this
  specialize this (fun state => ∀ m w, possibleMatch mPref wPref m w →
      ∀ s ∈ galeShapleyList mPref wPref, ∀ (nd : notDone s),
        state ∈ galeShapleyIterate s → ¬rejectedAtState nd m w)
  apply this
  clear this
  · intros s _ ih m w possible
    by_contra bad
    push_neg at bad
    obtain ⟨rejection_state, h_rjs, nd_rjs, rejection_before_s, w_rejected_m⟩ := bad
    unfold possibleMatch at possible
    obtain ⟨matching, m_matches_w, stable⟩ := possible
    unfold rejectedAtState at w_rejected_m
    obtain ⟨w_proposee, m_rejectee⟩ := w_rejected_m
    unfold rejectee at m_rejectee
    have w_matched: curMatch nd_rjs ≠ none := by
      by_contra bad
      simp [bad] at m_rejectee
    simp [w_matched] at m_rejectee
    let m' := newMatch nd_rjs
    have m'_rfl: m' = newMatch nd_rjs := by rfl
    have m'_ne_m: m' ≠ m := by
      by_contra bad
      simp [m'] at bad
      rw [bad] at m_rejectee
      split_ifs at m_rejectee <;> try contradiction
      case _ m_curMatch =>
      simp at m_rejectee
      have := curMatch_lemma nd_rjs m_curMatch
      have := didNotPropose nd_rjs (by rw [this]; simp)
      exact this.symm m_rejectee
    have m'_proposed_or_matched:
        proposedAtState nd_rjs m' w ∨ curMatch nd_rjs = some m' := by
      have := newMatch_choices nd_rjs
      rw [← m'_rfl] at this
      rcases this with m'_proposed | m'_matched
      · left
        unfold proposedAtState
        exact ⟨m'_proposed, w_proposee⟩
      · tauto
    have w_prefers_m': (wPref w).symm m' < (wPref w).symm m := by
      simp [← m'_rfl] at m_rejectee
      simp [newMatch, (pref_invariant' _ rejection_state h_rjs).2, w_proposee] at m'_rfl
      split at m_rejectee
      · case _ m'_curMatch =>
        simp at m_rejectee
        simp [m'_curMatch, m_rejectee] at m'_rfl
        split at m'_rfl <;> try contradiction
        omega
      · simp [m_rejectee] at m'_rfl
        rcases m'_proposed_or_matched with m'_proposed | m'_matched <;> try contradiction
        unfold proposedAtState at m'_proposed
        rw [← m'_proposed.1] at m'_rfl
        split at m'_rfl <;> try contradiction
        by_contra
        have: (wPref w).symm m' = (wPref w).symm m := by omega
        exact m'_ne_m (Equiv.injective (wPref w).symm this)
    have: isUnstablePair mPref wPref matching m' w := by
      unfold isUnstablePair
      simp [(inverseProperty matching m w).mp m_matches_w, w_prefers_m']
      rcases h: matching m' with _ | w'
      · tauto  -- m' single in matching, we are done
      · simp
        have w'_ne_w: w' ≠ w := by
          by_contra bad
          rw [bad] at h
          exact m'_ne_m (matchingCondition' h m_matches_w)
        by_contra bad
        push_neg at bad
        have m'_prefers_w': (mPref m').symm w' < (mPref m').symm w := by
          by_contra bad2
          have: (mPref m').symm w' = (mPref m').symm w := by omega
          exact w'_ne_w (Equiv.injective (mPref m').symm this)
        clear bad
        have earlier_rejection: ∃ t ∈ galeShapleyList mPref wPref, ∃ nd_t: notDone t,
            rejection_state ∈ galeShapleyIterate t ∧ t ≠ rejection_state ∧
            rejectedAtState nd_t m' w' := by
          rcases m'_proposed_or_matched with m'_proposed | m'_matched
          · apply proposedImpliesRejectedByPreferred
            exact h_rjs
            exact m'_proposed
            exact m'_prefers_w'
          · apply matchedImpliesRejectedByPreferred
            exact h_rjs
            exact curMatch_lemma nd_rjs m'_matched
            rw [w_proposee]
            exact m'_prefers_w'
        obtain ⟨t, ht, nd_t, t_before_rejection, t_ne_rejection, w'_rejects_m'⟩ := earlier_rejection
        have s_ne_t: s ≠ t := by
          by_contra bad
          rw [bad] at rejection_before_s
          have eq := iterateAntisymmetry ht h_rjs t_before_rejection rejection_before_s
          exact t_ne_rejection eq
        specialize ih t ht s_ne_t (by
          apply iterateTransitivity
          exact t_before_rejection
          exact rejection_before_s
        ) m' w' (by
          unfold possibleMatch
          use matching
        ) t ht nd_t (by apply iterateReflexivity)
        exact ih w'_rejects_m'
    unfold isStableMatching at stable
    exact stable m' w this
  · exact state_in_gsList

lemma neverRejectedByPossibleMatch: possibleMatch mPref wPref m w →
    neverRejectedFromState (initialState mPref wPref) m w := by
  intro possible
  have := neverRejectedByPossibleMatch' mPref wPref (galeShapleyFinalState mPref wPref) m w ?_ possible
  by_contra bad
  unfold neverRejectedFromState at bad
  push_neg at bad
  obtain ⟨s, hs, nd, rejected⟩ := bad
  simp at hs
  specialize this s hs nd
  unfold galeShapleyFinalState galeShapleyList at this
  rw [tailLast s hs] at this
  simp [List.getLast_mem (galeShapleyIterateNonEmpty _)] at this
  exact this rejected

  unfold galeShapleyFinalState
  exact List.getLast_mem (galeShapleyListNonEmpty mPref wPref)

theorem proposerOptimal (matching: Matching M W) (stable: isStableMatching mPref wPref matching):
    ∀ m, match galeShapley mPref wPref m with
         | none => matching m = none
         | some w => ∀ w', matching m = some w' → (mPref m).symm w ≤ (mPref m).symm w' := by
  intro m
  split
  · case _ m_gs_single =>
    by_contra bad
    push_neg at bad
    rw [Option.ne_none_iff_exists] at bad
    obtain ⟨w, m_matches_w⟩ := bad

    -- m is single so must have been rejected by everybody
    have m_rejected_by_all := singleImpliesRejectedByAll mPref wPref m_gs_single
    specialize m_rejected_by_all w
    obtain ⟨s, hs, h, w_rejected_m⟩ := m_rejected_by_all
    have m_w_possible_match: possibleMatch mPref wPref m w := by
      unfold possibleMatch
      use matching
      exact ⟨m_matches_w.symm, stable⟩
    have := neverRejectedByPossibleMatch mPref wPref m_w_possible_match
    unfold neverRejectedFromState at this
    specialize this s hs h
    contradiction
  · case _ w m_gs_matches_w =>
    intros w' m_matches_w'
    have proposalIndexEq := (galeShapleyFinalState mPref wPref).matchedLastProposed m w m_gs_matches_w
    simp at proposalIndexEq
    have := (proposeIndexInequality mPref wPref m w).mpr
    simp at this
    specialize this (by omega)
    unfold proposed at this
    obtain ⟨s, hs, h, m_proposed_w⟩ := this
    have never_rejected_by_w: neverRejectedFromState (initialState mPref wPref) m w := by
      have gs_is_possible_match: possibleMatch mPref wPref m w := by
        unfold possibleMatch
        use (galeShapley mPref wPref)
        exact ⟨m_gs_matches_w, galeShapleyGivesStableMatching mPref wPref⟩
      exact neverRejectedByPossibleMatch mPref wPref gs_is_possible_match
    have := proposedNeverRejectedImpliesFinalMatch h m_proposed_w ?_
    · have m_w'_possible_match: possibleMatch mPref wPref m w' := by
        unfold possibleMatch
        use matching
      have never_rejected_by_w' := neverRejectedByPossibleMatch mPref wPref m_w'_possible_match
      by_contra bad
      push_neg at bad
      have := (proposeIndexInequality mPref wPref m w').mpr (by omega)
      obtain ⟨s', hs', h', m_proposed_w'⟩ := this
      have m_gs_matches_w' := proposedNeverRejectedImpliesFinalMatch h' m_proposed_w' ?_
      rw [← tailLast s' hs'] at m_gs_matches_w'
      simp at m_gs_matches_w'
      rw [m_gs_matches_w] at m_gs_matches_w'
      simp at m_gs_matches_w'
      rw [m_gs_matches_w'] at bad
      omega

      exact neverRejectedFuture never_rejected_by_w' s' hs'
    · exact neverRejectedFuture never_rejected_by_w s hs

theorem receiverPessimal (matching: Matching M W) (stable: isStableMatching mPref wPref matching):
    ∀ w, match inverseMatching (galeShapley mPref wPref) w with
          | none => True
          | some m => ∀ m', inverseMatching matching w = some m' →
                (wPref w).symm m' ≤ (wPref w).symm m := by
  intro w
  rcases h: inverseMatching (galeShapley mPref wPref) w with _ | m
  · simp
  · simp
    intro m' w_matches_m'

    have proposer_optimal := proposerOptimal mPref wPref matching stable m
    rw [← inverseProperty _ _ _] at h
    simp [h] at proposer_optimal

    unfold isStableMatching at stable
    specialize stable m w
    unfold isUnstablePair at stable
    unfold_let at stable
    set_option push_neg.use_distrib true in push_neg at stable
    rw [w_matches_m'] at stable
    simp at stable

    rcases h2: matching m with _ | w'
    · tauto
    · simp [h2] at stable
      rcases stable <;> try assumption
      specialize proposer_optimal w' h2
      have: w' = w := by
        have: (mPref m).symm w = (mPref m).symm w' := by omega
        exact Equiv.injective (mPref m).symm this.symm
      rw [this] at h2
      rw [← inverseProperty _ _ _] at w_matches_m'
      have := matchingCondition' w_matches_m' h2
      rw [this]
