import React, { useState } from "react";
import axios from "axios";

// Use environment variable for backend URL
const API_URL = "/api";

function AddEmployee({ refreshList }) {
  const [empno, setEmpno] = useState("");
  const [empname, setEmpname] = useState("");
  const [salary, setSalary] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      await axios.post(`${API_URL}/employees/add`, {
        empno,
        empname,
        salary,
      });
      const res = await axios.get(`${API_URL}/employees`);
      alert("Employee added successfully!");
      setEmpno("");
      setEmpname("");
      setSalary("");
      refreshList();
    } catch (err) {
      console.error("Error adding employee:", err);
      alert("Failed to add employee. See console for details.");
    }
  };

  return (
    <div>
      <h4>Add Employee</h4>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          className="form-control mb-2"
          placeholder="Emp No"
          value={empno}
          onChange={(e) => setEmpno(e.target.value)}
          required
        />
        <input
          type="text"
          className="form-control mb-2"
          placeholder="Emp Name"
          value={empname}
          onChange={(e) => setEmpname(e.target.value)}
          required
        />
        <input
          type="text"
          className="form-control mb-2"
          placeholder="Salary"
          value={salary}
          onChange={(e) => setSalary(e.target.value)}
          required
        />
        <button type="submit" className="btn btn-success">
          Add Employee
        </button>
      </form>
    </div>
  );
}

export default AddEmployee;

