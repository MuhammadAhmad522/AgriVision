import React, { useEffect } from 'react';
import { useFleetFields } from '../hooks/useFleet';
import { useFleetStore } from '../store/fleetStore';
import { useAuth } from '../auth/AuthContext';

/**
 * All this component used to do was copy query results into Zustand through five effects.
 * That mirror is gone — views read the queries directly via the useFleet hooks — so the
 * only work left here is the two things that genuinely are app-level side effects:
 * defaulting a non-staff user onto their first field, and dropping the previous user's
 * selection at sign-out (which the old store kept, briefly showing one account's field
 * name to the next account that signed in).
 */
export const FarmDataSync: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user } = useAuth();
  const isStaff = user?.role === 'admin' || user?.role === 'agronomist';

  const { fields } = useFleetFields();
  const activeFieldId = useFleetStore((s) => s.activeFieldId);
  const setActiveField = useFleetStore((s) => s.setActiveField);

  useEffect(() => {
    if (!isStaff && !activeFieldId && fields.length > 0) {
      setActiveField(fields[0]);
    }
  }, [isStaff, activeFieldId, fields, setActiveField]);

  useEffect(() => {
    if (!user) useFleetStore.getState().reset();
  }, [user]);

  return <>{children}</>;
};
