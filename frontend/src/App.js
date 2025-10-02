import React, { useState } from "react";
import AddEmployee from "./components/AddEmployee";
import ListEmployees from "./components/ListEmployees";
import 'bootstrap/dist/css/bootstrap.min.css';

function App() {
  const [refreshFlag, setRefreshFlag] = useState(false);

  const refreshList = () => setRefreshFlag(!refreshFlag);

  return (
    <div className="container mt-4">
      <h2 className="text-center">Employee Management</h2>
      <AddEmployee refreshList={refreshList} />
      <hr />
      <ListEmployees refreshFlag={refreshFlag} />
    </div>
  );
}

export default App;

